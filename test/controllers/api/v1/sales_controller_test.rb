# frozen_string_literal: true

require "test_helper"

class Api::V1::SalesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @family.update!(business_mode_enabled: true)

    @user.api_keys.active.destroy_all
    @read_api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "mobile",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@read_api_key.id}")
    Redis.new.del("api_rate_limit:#{@write_api_key.id}")

    @product = Product.create!(
      family: @family,
      name: "Widget",
      sku: "WIDGET-01",
      buy_price: 10,
      sell_price: 20,
      currency: "pyg",
      stock: 10,
      min_stock: 2
    )

    @sale = Sale.create!(
      family: @family,
      account: accounts(:depository),
      client_name: "John Doe",
      currency: "pyg",
      sale_items_attributes: [
        { product_id: @product.id, quantity: 3, unit_price: 20 }
      ]
    )
  end

  test "should list sales" do
    get api_v1_sales_url, headers: api_headers(@read_api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |s| s["id"] == @sale.id }
  end

  test "should show sale with items and product details" do
    get api_v1_sale_url(@sale), headers: api_headers(@read_api_key)
    assert_response :success

    json_response = JSON.parse(response.body)["data"]
    assert_equal @sale.id, json_response["id"]
    assert_equal "draft", json_response["status"]
    assert_equal 60.0, json_response["total"]
    assert_equal 1, json_response["sale_items"].size
    assert_equal "Widget", json_response["sale_items"].first["product_name"]
  end

  test "should create draft sale" do
    assert_difference -> { Sale.count } => 1, -> { SaleItem.count } => 1 do
      post api_v1_sales_url,
           params: {
             sale: {
               client_name: "Jane Smith",
               currency: "pyg",
               account_id: accounts(:depository).id,
               sale_items_attributes: [
                 { product_id: @product.id, quantity: 2, unit_price: 20 }
               ]
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "draft", json_response["status"]
    assert_equal "Jane Smith", json_response["client_name"]
  end

  test "should complete sale and decrease product stock" do
    assert_equal 10, @product.reload.stock

    assert_difference -> { ProductStockMovement.count } => 1 do
      post complete_api_v1_sale_url(@sale), headers: api_headers(@write_api_key)
    end

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "completed", json_response["status"]

    assert_equal 7, @product.reload.stock
    movement = @product.stock_movements.last
    assert_equal "salida", movement.reason
    assert_equal(-3, movement.quantity_delta)
  end

  test "should cancel completed sale and restore product stock" do
    @sale.complete!
    assert_equal 7, @product.reload.stock

    assert_difference -> { ProductStockMovement.count } => 1 do
      post cancel_api_v1_sale_url(@sale), headers: api_headers(@write_api_key)
    end

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "cancelled", json_response["status"]

    assert_equal 10, @product.reload.stock
    movement = @product.stock_movements.last
    assert_equal "entrada", movement.reason
    assert_equal 3, movement.quantity_delta
  end

  test "should fail to complete sale with insufficient stock" do
    @product.update_columns(stock: 1) # Directly set stock lower than quantity (3)

    post complete_api_v1_sale_url(@sale), headers: api_headers(@write_api_key)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should fail to edit non-draft sale items" do
    @sale.complete!

    patch api_v1_sale_url(@sale),
          params: {
            sale: {
              client_name: "Attempt Edit",
              sale_items_attributes: [
                { product_id: @product.id, quantity: 5, unit_price: 20 }
              ]
            }
          },
          headers: api_headers(@write_api_key)

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should destroy draft sale" do
    assert_difference -> { Sale.count } => -1 do
      delete api_v1_sale_url(@sale), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
  end

  test "should fail to destroy completed sale" do
    @sale.complete!

    assert_no_difference -> { Sale.count } do
      delete api_v1_sale_url(@sale), headers: api_headers(@write_api_key)
    end

    assert_response :unprocessable_entity
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
