# Liquidaciones de tarjeta (Visa/Mastercard) exportadas por Upay, la
# procesadora de pagos que usa el negocio. Formato fijo (siempre las mismas
# 23 columnas, separador ";", montos con "." como separador de miles), así
# que a diferencia de TransactionImport no hay wizard de mapeo de columnas:
# se parsea directo por nombre de columna conocido.
#
# Por cada fila se generan hasta 2 movimientos:
#   1. Ingreso por el monto bruto de la venta, salvo que la fila matchee con
#      una Sale ya completada en el sistema (misma family, mismo total,
#      fecha cercana) -- en ese caso Sale#complete! ya creó ese ingreso, así
#      que acá solo se anota la conciliación en el Entry de esa Sale para no
#      duplicar el ingreso.
#   2. Egreso por la comisión total que cobró la procesadora (comisión + IVA
#      comisión + retención + IVA retención) -- esto la venta nunca lo
#      registra, sea cual sea el camino.
class UpayImport < Import
  RECONCILE_WINDOW = 3.days

  before_validation :set_upay_defaults, on: :create

  def import!
    raise "Account required for Upay import" unless account.present?

    transaction do
      new_transactions = []

      rows.each do |row|
        gross = row.gross_amount.to_d
        commission = row.commission_amount.to_d
        date = row.date_iso
        matched_sale = matching_sale_for(gross, date)

        if matched_sale
          annotate_matched_sale(matched_sale, row)
        else
          new_transactions << income_transaction(row, gross, date)
        end

        if commission > 0
          new_transactions << commission_transaction(row, commission, date)
        end
      end

      Transaction.import!(new_transactions, recursive: true) if new_transactions.any?
    end
  end

  def requires_csv_workflow?
    true
  end

  def column_keys
    %i[date name gross_amount commission_amount amount receipt_number card_brand]
  end

  def required_column_keys
    %i[date amount]
  end

  def mapping_steps
    []
  end

  # Bypassa el mecanismo genérico de *_col_label (pensado para que el
  # usuario mapee columnas arbitrarias) -- acá los headers de Upay son
  # siempre los mismos, así que se leen directo por nombre.
  def generate_rows_from_csv
    rows.destroy_all

    mapped_rows = csv_rows.map.with_index(1) do |row, index|
      gross = sanitize_number(row["Monto bruto"])
      net = sanitize_number(row["Monto neto"])
      commission = [ "Comisión", "IVA Comisión", "Retención", "IVA Retención" ]
        .sum { |col| sanitize_number(row[col]).presence&.to_d || 0.to_d }

      {
        source_row_number: index,
        date: row["Fecha de venta"].to_s,
        amount: net.to_s,
        gross_amount: gross.to_s,
        commission_amount: commission.to_s,
        currency: default_currency,
        name: upay_row_name(row),
        receipt_number: row["Boleta Nº"].to_s,
        auth_code: row["Código de autorización"].to_s,
        card_brand: row["Marca"].to_s,
        card_type: row["Tipo de tarjeta"].to_s,
        notes: upay_row_notes(row)
      }
    end

    rows.insert_all!(mapped_rows)
    # `rows.destroy_all` above cached the association as loaded-empty;
    # insert_all! bypasses AR entirely and doesn't invalidate that cache, so
    # anything reading `rows`/`rows_ordered` on this same in-memory object
    # afterwards (like import! in the same request) would see nothing until
    # a reload. reset here so every caller gets fresh data without having to
    # remember that.
    rows.reset
    update_column(:rows_count, rows.count)
  end

  private
    # Sin `||=`: Import#set_default_number_format (before_validation de la
    # clase base) corre antes que este callback y ya deja number_format en
    # "1,234.56" si estaba en blanco, así que un `||=` acá nunca pisaría ese
    # valor. UpayImport siempre usa el mismo formato fijo, forzarlo es seguro
    # (este callback solo corre on: :create).
    def set_upay_defaults
      self.col_sep = ";"
      self.date_format = "%d-%m-%Y"
      self.number_format = "1.234,56"
    end

    def upay_row_name(row)
      brand = row["Marca"].to_s
      card_type = row["Tipo de tarjeta"].to_s
      "Liquidación #{[ brand, card_type ].reject(&:blank?).join(' ')}".strip
    end

    def upay_row_notes(row)
      [
        row["Boleta Nº"].present? ? "Boleta Nº #{row['Boleta Nº']}" : nil,
        row["Código de autorización"].present? ? "Autorización #{row['Código de autorización']}" : nil
      ].compact.join(" · ")
    end

    def matching_sale_for(gross_amount, date_iso)
      target_date = Date.parse(date_iso)
      family.sales.completed
        .where(created_at: (target_date - RECONCILE_WINDOW).beginning_of_day..(target_date + RECONCILE_WINDOW).end_of_day)
        .find { |sale| sale.total == gross_amount }
    end

    def annotate_matched_sale(sale, row)
      return unless sale.entry

      reconciliation_note = "Conciliado con Upay -- Boleta Nº #{row.receipt_number}, Autorización #{row.auth_code}"
      return if sale.entry.notes.to_s.include?(reconciliation_note)

      combined_notes = [ sale.entry.notes.presence, reconciliation_note ].compact.join("\n")
      sale.entry.update!(notes: combined_notes)
    end

    def income_transaction(row, gross, date)
      Transaction.new(
        category: sale_category,
        entry: Entry.new(
          account: account,
          date: date,
          amount: -gross,
          name: row.name,
          currency: row.currency,
          notes: row.notes,
          import: self,
          import_locked: true
        )
      )
    end

    def commission_transaction(row, commission, date)
      Transaction.new(
        category: commission_category,
        entry: Entry.new(
          account: account,
          date: date,
          amount: commission,
          name: "Comisión #{[ row.card_brand, row.card_type ].reject(&:blank?).join(' ')}".strip,
          currency: row.currency,
          notes: row.notes,
          import: self,
          import_locked: true
        )
      )
    end

    def sale_category
      @sale_category ||= family.categories.find_or_create_by!(name: "Ventas con tarjeta") do |category|
        category.color = "#10b981"
        category.lucide_icon = "credit-card"
      end
    end

    def commission_category
      @commission_category ||= family.categories.find_or_create_by!(name: "Comisiones de tarjeta") do |category|
        category.color = "#f97316"
        category.lucide_icon = "percent"
      end
    end
end
