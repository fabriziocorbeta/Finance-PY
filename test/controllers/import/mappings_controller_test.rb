require "test_helper"

class Import::MappingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)

    @import = imports(:transaction)
  end

  test "updates mapping" do
    mapping = import_mappings(:one)
    new_category = categories(:income)

    patch import_mapping_path(@import, mapping), params: {
      import_mapping: {
        mappable_type: "Category",
        mappable_id: new_category.id,
        key: "Food"
      }
    }

    mapping.reload

    assert_equal new_category, mapping.mappable
    assert_equal "Food", mapping.key

    assert_redirected_to import_confirm_path(@import)
  end

  test "ignores unknown mappable_type instead of constantizing arbitrary input" do
    mapping = import_mappings(:one)

    assert_nothing_raised do
      patch import_mapping_path(@import, mapping), params: {
        import_mapping: {
          mappable_type: "NotARealConstant",
          mappable_id: @user.id,
          key: "Food"
        }
      }
    end

    assert_redirected_to import_confirm_path(@import)

    mapping.reload
    assert_nil mapping.mappable
  end

  test "ignores unknown mapping type instead of constantizing arbitrary input" do
    mapping = import_mappings(:one)

    assert_nothing_raised do
      patch import_mapping_path(@import, mapping), params: {
        import_mapping: {
          type: "NotARealConstant",
          mappable_id: Import::Mapping::CREATE_NEW_KEY,
          key: "Food"
        }
      }
    end

    assert_redirected_to import_confirm_path(@import)

    mapping.reload
    assert_equal false, mapping.create_when_empty
  end
end
