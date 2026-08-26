class CreateFuelLogLinesAndMigrateHistoricalData < ActiveRecord::Migration[7.2]
  class MigrationFuelLog < ActiveRecord::Base
    self.table_name = "fuel_logs"
    has_many :fuel_log_lines, class_name: "CreateFuelLogLinesAndMigrateHistoricalData::MigrationFuelLogLine", foreign_key: "fuel_log_id"
    belongs_to :entry, class_name: "CreateFuelLogLinesAndMigrateHistoricalData::MigrationEntry", optional: true
  end

  class MigrationFuelLogLine < ActiveRecord::Base
    self.table_name = "fuel_log_lines"
    belongs_to :fuel_log, class_name: "CreateFuelLogLinesAndMigrateHistoricalData::MigrationFuelLog"
  end

  class MigrationEntry < ActiveRecord::Base
    self.table_name = "entries"
    belongs_to :transaction_record, class_name: "CreateFuelLogLinesAndMigrateHistoricalData::MigrationTransaction", foreign_key: "entryable_id", optional: true
  end

  class MigrationTransaction < ActiveRecord::Base
    self.table_name = "transactions"
  end

  def change
    create_table :fuel_log_lines, id: :uuid do |t|
      t.references :fuel_log, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :fuel_type, null: false, default: "nafta"
      t.decimal :liters, precision: 10, scale: 2, null: false
      t.decimal :cost, precision: 19, scale: 4, null: false

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        migrate_existing_fuel_logs
      end
    end
  end

  private

    def infer_fuel_type(notes)
      return "nafta", false if notes.blank?

      down = notes.downcase
      if down.include?("alcohol") || down.include?("alcool") || down.include?("etanol")
        [ "alcohol", true ]
      elsif down.include?("nafta") || down.include?("gasolina") || down.include?("gasoline")
        [ "nafta", true ]
      elsif down.include?("gnc")
        [ "gnc", true ]
      elsif down.include?("diesel") || down.include?("gasoil")
        [ "diesel", true ]
      else
        [ "nafta", false ]
      end
    end

    def migrate_existing_fuel_logs
      MigrationFuelLog.reset_column_information
      MigrationFuelLogLine.reset_column_information

      # Group by fleet_vehicle_id, odometer, logged_at
      grouped_logs = MigrationFuelLog.all.group_by { |log| [ log.fleet_vehicle_id, log.odometer, log.logged_at ] }

      affected_account_ids = grouped_logs.values.select { |logs| logs.size > 1 }.flat_map { |logs| logs.map(&:account_id) }.compact.uniq

      grouped_logs.each do |_key, logs|
        primary_log = logs.first

        logs.each_with_index do |log, index|
          fuel_type, explicit = infer_fuel_type(log.notes)
          unless explicit
            Rails.logger.warn("[FuelLog Migration Review Required] FuelLog ID: #{log.id}, notes: '#{log.notes}' defaulted to 'nafta'")
          end

          if index == 0
            # Create line for primary log
            MigrationFuelLogLine.create!(
              fuel_log_id: primary_log.id,
              fuel_type: fuel_type,
              liters: log.liters,
              cost: log.cost,
              created_at: log.created_at || Time.current,
              updated_at: log.updated_at || Time.current
            )
          else
            # Merge secondary log into primary log
            MigrationFuelLogLine.create!(
              fuel_log_id: primary_log.id,
              fuel_type: fuel_type,
              liters: log.liters,
              cost: log.cost,
              created_at: log.created_at || Time.current,
              updated_at: log.updated_at || Time.current
            )

            # Combine notes
            if log.notes.present?
              combined_notes = [ primary_log.notes, log.notes ].compact.reject(&:blank?).uniq.join(" + ")
              primary_log.update_columns(notes: combined_notes)
            end

            entry_id_to_cleanup = log.entry_id

            # Delete secondary fuel log first so entry FK reference is cleared
            log.destroy

            # Clean up secondary log's associated entry and transaction if present
            if entry_id_to_cleanup.present?
              entry = MigrationEntry.find_by(id: entry_id_to_cleanup)
              if entry
                txn_id = entry.entryable_id
                entry.destroy
                MigrationTransaction.where(id: txn_id).destroy_all if txn_id.present?
              end
            end
          end
        end

        # Update primary log totals
        total_liters = primary_log.fuel_log_lines.sum(:liters)
        total_cost = primary_log.fuel_log_lines.sum(:cost)

        primary_log.update_columns(
          liters: total_liters,
          cost: total_cost
        )

        if primary_log.entry_id.present?
          entry = MigrationEntry.find_by(id: primary_log.entry_id)
          entry&.update_columns(amount: total_cost)
        end
      end

      if affected_account_ids.any?
        Account.where(id: affected_account_ids).find_each(&:sync_later)
      end
    end
end
