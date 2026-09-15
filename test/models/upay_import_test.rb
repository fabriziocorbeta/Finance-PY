require "test_helper"

class UpayImportTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @product = products(:dylan_product_1)
  end

  # Formato real exportado por Upay: separador ";", CRLF, montos con "." como
  # separador de miles. Sacado de Transacciones_Liquidaciones_14_09_2026.csv.
  def upay_csv(rows)
    header = "Nombre de comercio;Código de comercio;Fecha de venta;Hora de venta;Boleta Nº;Código de autorización;Monto bruto;Monto neto;Comisión;IVA Comisión;Retención;IVA Retención;Marca;Tipo de tarjeta;Número de tarjeta;Fecha de Acreditación;Estado de pago;Nro. de referencia de la Factura;Nro. de comprobante de pago;Código de cadena;Trx ID;Canal;Fuente de modo de entrada"
    ([ header ] + rows).join("\r\n")
  end

  def sample_row(gross: "35.000", net: "34.230", commission: "700", iva_commission: "70", retention: "0", iva_retention: "0", date: "31-08-2026", receipt: "624402298749", auth: "444605", brand: "VISA", card_type: "Débito")
    "CD Co;900000000307831;#{date};23:08:49;#{receipt};#{auth};#{gross};#{net};#{commission};#{iva_commission};#{retention};#{iva_retention};#{brand};#{card_type};45217603XXXX5913;2026-09-01T10:41:07;Aprobado;;31972346881588;GGUGUB;;;READER"
  end

  test "generate_rows_from_csv parses fixed Upay headers directly" do
    import = UpayImport.create!(family: @family, account: @account)
    import.raw_file_str = upay_csv([ sample_row ])
    import.save!(validate: false)

    import.generate_rows_from_csv

    assert_equal 1, import.rows_count
    row = import.reload.rows.first

    assert_equal "31-08-2026", row.date
    assert_equal "34230", row.amount
    assert_equal "35000", row.gross_amount
    assert_equal 770.to_d, row.commission_amount.to_d # 700 + 70 + 0 + 0
    assert_equal "624402298749", row.receipt_number
    assert_equal "444605", row.auth_code
    assert_equal "VISA", row.card_brand
    assert_equal "Débito", row.card_type
  end

  test "generate_rows_from_csv sums all four commission components" do
    import = UpayImport.create!(family: @family, account: @account)
    import.raw_file_str = upay_csv([
      sample_row(commission: "2.320", iva_commission: "232", retention: "800", iva_retention: "727")
    ])
    import.save!(validate: false)

    import.generate_rows_from_csv

    assert_equal 4079.to_d, import.reload.rows.first.commission_amount.to_d # 2320+232+800+727
  end

  test "import! creates income and commission entries when there is no matching sale" do
    import = UpayImport.create!(family: @family, account: @account)
    import.raw_file_str = upay_csv([ sample_row ])
    import.save!(validate: false)
    import.generate_rows_from_csv
    import.reload

    assert_difference -> { Entry.count }, 2 do
      import.import!
    end

    entries = @account.entries.where(import: import).order(:amount)
    income_entry = entries.find { |e| e.amount.negative? }
    commission_entry = entries.find { |e| e.amount.positive? }

    assert_equal(-35000, income_entry.amount)
    assert_equal 770, commission_entry.amount
    assert_equal "Ventas con tarjeta", income_entry.transaction.category.name
    assert_equal "Comisiones de tarjeta", commission_entry.transaction.category.name
  end

  test "import! skips the duplicate income entry when a matching completed Sale exists" do
    sale = Sale.create!(family: @family, account: @account, client_name: "Test Client")
    sale.sale_items.create!(product: @product, quantity: 1, unit_price: 35000)
    sale.complete!
    assert_equal 35000, sale.total

    import = UpayImport.create!(family: @family, account: @account)
    import.raw_file_str = upay_csv([ sample_row(gross: "35.000", date: Date.current.strftime("%d-%m-%Y")) ])
    import.save!(validate: false)
    import.generate_rows_from_csv
    import.reload

    assert_difference -> { Entry.count }, 1 do # solo la comisión, no el ingreso duplicado
      import.import!
    end

    sale.entry.reload
    assert_includes sale.entry.notes.to_s, "Conciliado con Upay"
    assert_includes sale.entry.notes.to_s, "624402298749"
  end
end
