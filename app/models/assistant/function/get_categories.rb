class Assistant::Function::GetCategories < Assistant::Function
  class << self
    def name
      "get_categories"
    end

    def description
      <<~INSTRUCTIONS
        Use this to get the family's category hierarchy (id, name, parent_name, full_name) ordered alphabetically by hierarchy.

        This is useful when you need to inspect available categories or suggest a category for a transaction or invoice.
      INSTRUCTIONS
    end
  end

  def call(params = {})
    categories = family.categories.includes(:parent).alphabetically_by_hierarchy.map do |category|
      {
        id: category.id,
        name: category.name,
        parent_name: category.parent&.name,
        full_name: category.name_with_parent
      }
    end

    {
      categories: categories,
      count: categories.size
    }
  end
end
