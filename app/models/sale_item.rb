class SaleItem < ApplicationRecord
  belongs_to :sale
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :sale_must_be_draft
  validate :product_belongs_to_family

  before_destroy :prevent_destroy_if_sale_not_draft

  def subtotal
    quantity * unit_price
  end

  private

    # Defense in depth next to row level security: an item can never point at a
    # product owned by another family.
    def product_belongs_to_family
      return if product.nil? || sale.nil?

      errors.add(:product, "must belong to the same family") unless product.family_id == sale.family_id
    end

    def sale_must_be_draft
      if sale.present? && !sale.draft?
        errors.add(:base, "Cannot modify items if the sale is not in draft status")
      end
    end

    def prevent_destroy_if_sale_not_draft
      if sale.present? && !sale.draft?
        errors.add(:base, "Cannot remove items if the sale is not in draft status")
        throw :abort
      end
    end
end
