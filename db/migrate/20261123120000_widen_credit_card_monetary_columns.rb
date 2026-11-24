# frozen_string_literal: true

class WidenCreditCardMonetaryColumns < ActiveRecord::Migration[7.2]
  def up
    change_column :credit_cards, :available_credit, :decimal, precision: 19, scale: 4
    change_column :credit_cards, :minimum_payment, :decimal, precision: 19, scale: 4
    change_column :credit_cards, :annual_fee, :decimal, precision: 19, scale: 4
  end

  def down
    change_column :credit_cards, :available_credit, :decimal, precision: 10, scale: 2
    change_column :credit_cards, :minimum_payment, :decimal, precision: 10, scale: 2
    change_column :credit_cards, :annual_fee, :decimal, precision: 10, scale: 2
  end
end
