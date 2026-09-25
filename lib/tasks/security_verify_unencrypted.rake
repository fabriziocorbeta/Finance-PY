# frozen_string_literal: true

namespace :security do
  desc "Verifies and counts unencrypted rows for models with encrypted attributes"
  task verify_unencrypted: :environment do
    models_and_attributes = {
      User => [ :email, :unconfirmed_email, :otp_secret ],
      Invitation => [ :token, :email ],
      MercuryItem => [ :token ],
      LunchflowItem => [ :api_key ],
      CoinbaseItem => [ :api_key ],
      SophtronItem => [ :user_id, :access_key ],
      SnaptradeItem => [ :client_id, :consumer_key ],
      IndexaCapitalItem => [ :password, :api_token ],
      EnableBankingItem => [ :client_certificate, :session_id ],
      CoinstatsItem => [ :api_key ],
      BinanceItem => [ :api_key ],
      PlaidItem => [ :access_token ],
      SimplefinItem => [ :access_url ]
    }

    puts "=========================================================="
    puts "Active Record Encryption Verification - Unencrypted Counts"
    puts "=========================================================="

    total_unencrypted = 0

    models_and_attributes.each do |model, attrs|
      next unless model.table_exists?

      attrs.each do |attr|
        count = 0
        model.find_each do |record|
          raw_val = record.read_attribute_before_type_cast(attr)
          next if raw_val.blank?

          # Check if the raw stored value starts with ActiveRecord::Encryption envelope marker
          unless raw_val.to_s.start_with?("{\"p\":") || raw_val.to_s.start_with?("{\"v\":")
            count += 1
          end
        end

        puts sprintf("%-25s %-20s : %d unencrypted rows", model.name, attr, count)
        total_unencrypted += count
      end
    end

    puts "----------------------------------------------------------"
    puts "Total unencrypted values across models: #{total_unencrypted}"
    puts "=========================================================="
  end
end
