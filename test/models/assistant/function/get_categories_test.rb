require "test_helper"

class Assistant::Function::GetCategoriesTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::GetCategories.new(@user)
  end

  test "returns family categories ordered alphabetically by hierarchy" do
    parent = @family.categories.create!(name: "Alimentacion Test", color: "#f97316", lucide_icon: "utensils")
    child = @family.categories.create!(name: "Supermercado Test", parent: parent, color: "#f97316", lucide_icon: "shopping-bag")

    result = @fn.call

    assert result[:categories].is_a?(Array)
    assert_equal result[:categories].size, result[:count]

    child_entry = result[:categories].find { |c| c[:id] == child.id }
    assert_not_nil child_entry
    assert_equal "Supermercado Test", child_entry[:name]
    assert_equal "Alimentacion Test", child_entry[:parent_name]
    assert_equal "Alimentacion Test > Supermercado Test", child_entry[:full_name]
  end
end
