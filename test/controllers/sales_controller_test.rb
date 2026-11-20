require "test_helper"

class SalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @family_admin = users(:family_admin)
    @dylan_family = families(:dylan_family)

    # Enable business mode for the main test family
    @dylan_family.update!(business_mode_enabled: true)

    sign_in @family_admin

    @product = @dylan_family.products.create!(
      name: "Test Product",
      buy_price: 10,
      sell_price: 20,
      stock: 50
    )

    @sale = @dylan_family.sales.create!(
      client_name: "Test Client",
      status: "draft",
      account: accounts(:depository)
    )

    @sale_item = @sale.sale_items.create!(
      product: @product,
      quantity: 5,
      unit_price: 20
    )
  end

  test "should get index" do
    get sales_url
    assert_response :success
  end

  test "should get new" do
    get new_sale_url
    assert_response :success
  end

  test "should create sale" do
    assert_difference("Sale.count", 1) do
      post sales_url, params: {
        sale: {
          client_name: "New Client",
          account_id: accounts(:depository).id,
          sale_items_attributes: {
            "0" => {
              product_id: @product.id,
              quantity: 2,
              unit_price: 20
            }
          }
        }
      }
    end

    sale = Sale.order(:created_at).last
    assert_redirected_to sale_url(sale)
    assert_equal "New Client", sale.client_name
    assert_equal 1, sale.sale_items.count
  end

  test "should create sale via json and return sale_number" do
    assert_difference("Sale.count", 1) do
      post sales_url, params: {
        sale: {
          client_name: "JSON Client",
          account_id: accounts(:depository).id,
          sale_items_attributes: {
            "0" => {
              product_id: @product.id,
              quantity: 1,
              unit_price: 20
            }
          }
        }
      }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["id"].present?
    assert body["sale_number"].present?
  end

  test "should return json errors on invalid sale" do
    assert_no_difference("Sale.count") do
      post sales_url, params: {
        sale: {
          client_name: "Invalid Client",
          sale_items_attributes: {
            "0" => {
              product_id: @product.id,
              quantity: 0,
              unit_price: 20
            }
          }
        }
      }, as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert body["errors"].present?
  end

  test "should show sale" do
    get sale_url(@sale)
    assert_response :success
  end

  test "should get edit" do
    get edit_sale_url(@sale)
    assert_response :success
  end

  test "should update sale" do
    patch sale_url(@sale), params: {
      sale: {
        client_name: "Updated Client"
      }
    }
    assert_redirected_to sale_url(@sale)
    @sale.reload
    assert_equal "Updated Client", @sale.client_name
  end

  test "should not update sale items if not draft" do
    @sale.complete!
    @sale.reload

    patch sale_url(@sale), params: {
      sale: {
        client_name: "Another Update",
        sale_items_attributes: {
          "0" => {
            id: @sale_item.id,
            quantity: 10
          }
        }
      }
    }

    assert_redirected_to sale_url(@sale)
    @sale.reload
    @sale_item.reload
    assert_equal "Another Update", @sale.client_name
    assert_equal 5, @sale_item.quantity # Should not change
  end

  test "should complete sale" do
    assert_difference("ProductStockMovement.count", 1) do
      patch complete_sale_url(@sale)
    end

    assert_redirected_to sale_url(@sale)
    @sale.reload
    assert_equal "completed", @sale.status

    movement = ProductStockMovement.order(:created_at).last
    assert_equal "salida", movement.reason
    assert_equal -5, movement.quantity_delta
  end

  test "should cancel sale" do
    @sale.complete!
    @sale.reload

    assert_difference("ProductStockMovement.count", 1) do
      patch cancel_sale_url(@sale)
    end

    assert_redirected_to sale_url(@sale)
    @sale.reload
    assert_equal "cancelled", @sale.status

    movement = ProductStockMovement.order(:created_at).last
    assert_equal "entrada", movement.reason
    assert_equal 5, movement.quantity_delta
  end

  test "should destroy sale" do
    assert_difference("Sale.count", -1) do
      delete sale_url(@sale)
    end

    assert_redirected_to sales_url
  end

  test "redirects when business mode is disabled" do
    @dylan_family.update!(business_mode_enabled: false)

    get sales_url
    assert_redirected_to root_url
    assert_equal "This feature isn't enabled for your family.", flash[:alert]
  end

  test "cannot access sale from another family" do
    other_family = Family.create!(name: "Other Family", business_mode_enabled: true)
    other_account = Account.create!(family: other_family, name: "Cuenta Other", currency: "USD", balance: 0, accountable: Depository.new)
    other_sale = other_family.sales.create!(
      client_name: "Other Client",
      status: "draft",
      account: other_account
    )

    get sale_url(other_sale)
    assert_response :not_found

    patch sale_url(other_sale), params: { sale: { client_name: "Hacked" } }
    assert_response :not_found
    assert_equal "Other Client", other_sale.reload.client_name
  end

  test "cannot attach an account from another family on create" do
    foreign = families(:empty).accounts.create!(
      name: "Foreign", balance: 0, currency: "USD",
      accountable: Depository.new
    )

    assert_no_difference "Sale.count" do
      post sales_url, params: { sale: { client_name: "X", account_id: foreign.id } }
    end
  end

  test "family member cannot create sale on read-only account" do
    sign_in users(:family_member)

    assert_no_difference "Sale.count" do
      post sales_url, params: {
        sale: {
          client_name: "Read Only Sale",
          account_id: accounts(:credit_card).id,
          sale_items_attributes: {
            "0" => { product_id: @product.id, quantity: 1, unit_price: 20 }
          }
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "family member can create sale on writable shared account" do
    sign_in users(:family_member)

    assert_difference("Sale.count", 1) do
      post sales_url, params: {
        sale: {
          client_name: "Writable Share Sale",
          account_id: accounts(:depository).id,
          sale_items_attributes: {
            "0" => { product_id: @product.id, quantity: 1, unit_price: 20 }
          }
        }
      }
    end
    assert_redirected_to sale_url(Sale.order(:created_at).last)
  end

  test "family member cannot mutate sale on read-only account" do
    read_only_sale = @dylan_family.sales.create!(
      client_name: "Locked Sale",
      status: "draft",
      account: accounts(:credit_card)
    )
    read_only_sale.sale_items.create!(product: @product, quantity: 1, unit_price: 20)

    sign_in users(:family_member)

    patch sale_url(read_only_sale), params: { sale: { client_name: "Tampered" } }
    assert_response :forbidden
    assert_equal "Locked Sale", read_only_sale.reload.client_name

    patch complete_sale_url(read_only_sale)
    assert_response :forbidden
    assert_equal "draft", read_only_sale.reload.status

    patch cancel_sale_url(read_only_sale)
    assert_response :forbidden
    assert_equal "draft", read_only_sale.reload.status

    assert_no_difference "Sale.count" do
      delete sale_url(read_only_sale)
    end
    assert_response :forbidden
  end

  test "new sale form only lists writable accounts for family member" do
    sign_in users(:family_member)

    get new_sale_url
    assert_response :success
    # Scope to the account picker's options (DS::Select renders role=option
    # items, not a native <select>): the layout sidebar also links every account
    # the member can see (read-only ones included), so a whole-body match is wrong.
    assert_select "[role='option'][data-value=?]", accounts(:depository).id.to_s, count: 1
    assert_select "[role='option'][data-value=?]", accounts(:credit_card).id.to_s, count: 0
  end

  test "should upload, view, download, and delete invoice photo on sale" do
    file = fixture_file_upload("receipt.jpg", "image/jpeg")

    post sale_invoice_photo_url(@sale), params: { invoice_photo: file }
    assert_redirected_to sale_url(@sale)
    assert @sale.reload.invoice_photo.attached?
    assert_equal "receipt.jpg", @sale.invoice_photo.filename.to_s

    get sale_invoice_photo_url(@sale)
    assert_response :success
    assert_equal "image/jpeg", response.media_type
    assert_match(/inline/, response.headers["Content-Disposition"])

    get sale_invoice_photo_url(@sale, disposition: "attachment")
    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"])

    delete sale_invoice_photo_url(@sale)
    assert_redirected_to sale_url(@sale)
    assert_not @sale.reload.invoice_photo.attached?

    get sale_invoice_photo_url(@sale)
    assert_response :not_found
  end

  test "should attach invoice photo when creating sale via form" do
    file = fixture_file_upload("receipt.jpg", "image/jpeg")

    assert_difference("Sale.count", 1) do
      post sales_url, params: {
        sale: {
          client_name: "Photo Client",
          account_id: accounts(:depository).id,
          invoice_photo: file,
          sale_items_attributes: {
            "0" => {
              product_id: @product.id,
              quantity: 1,
              unit_price: 20
            }
          }
        }
      }
    end

    sale = Sale.order(:created_at).last
    assert sale.invoice_photo.attached?
    assert_equal "receipt.jpg", sale.invoice_photo.filename.to_s
  end

  test "should reject invalid invoice photo content type on sale" do
    invalid_file = fixture_file_upload("test.txt", "text/plain")

    post sale_invoice_photo_url(@sale), params: { invoice_photo: invalid_file }
    assert_redirected_to sale_url(@sale)
    assert_match(/JPEG, PNG, GIF, WebP image or PDF/, flash[:alert].to_s)
    assert_not @sale.reload.invoice_photo.attached?
  end

  test "cannot upload or delete invoice photo on read-only account or other family sale" do
    read_only_sale = @dylan_family.sales.create!(
      client_name: "Locked Sale",
      status: "draft",
      account: accounts(:credit_card)
    )
    file = fixture_file_upload("receipt.jpg", "image/jpeg")

    sign_in users(:family_member)

    post sale_invoice_photo_url(read_only_sale), params: { invoice_photo: file }
    assert_response :forbidden
    assert_not read_only_sale.reload.invoice_photo.attached?

    delete sale_invoice_photo_url(read_only_sale)
    assert_response :forbidden

    other_family = Family.create!(name: "Other Family", business_mode_enabled: true)
    other_account = Account.create!(family: other_family, name: "Cuenta Other", currency: "USD", balance: 0, accountable: Depository.new)
    other_sale = other_family.sales.create!(client_name: "Other", status: "draft", account: other_account)

    get sale_invoice_photo_url(other_sale)
    assert_response :not_found

    post sale_invoice_photo_url(other_sale), params: { invoice_photo: file }
    assert_response :not_found
  end
end
