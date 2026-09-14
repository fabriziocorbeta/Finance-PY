# frozen_string_literal: true

require "test_helper"

class Api::V1::PurchaseOrdersControllerTest < ActionDispatch::IntegrationTest
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
      name: "Widget Material",
      sku: "RAW-01",
      buy_price: 10,
      sell_price: 20,
      currency: "pyg",
      stock: 5,
      min_stock: 2
    )

    @purchase_order = PurchaseOrder.create!(
      family: @family,
      supplier_name: "Acme Supplies",
      currency: "pyg",
      account: accounts(:depository),
      purchase_order_items_attributes: [
        { product_id: @product.id, quantity: 10, unit_cost: 8 }
      ]
    )
  end

  test "should list purchase orders" do
    get api_v1_purchase_orders_url, headers: api_headers(@read_api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |po| po["id"] == @purchase_order.id }
  end

  test "should show purchase order with items and product details" do
    get api_v1_purchase_order_url(@purchase_order), headers: api_headers(@read_api_key)
    assert_response :success

    json_response = JSON.parse(response.body)["data"]
    assert_equal @purchase_order.id, json_response["id"]
    assert_equal "draft", json_response["status"]
    assert_equal 80.0, json_response["total"]
    assert_equal 1, json_response["purchase_order_items"].size
    assert_equal "Widget Material", json_response["purchase_order_items"].first["product_name"]
  end

  test "should create draft purchase order" do
    assert_difference -> { PurchaseOrder.count } => 1, -> { PurchaseOrderItem.count } => 1 do
      post api_v1_purchase_orders_url,
           params: {
             purchase_order: {
               supplier_name: "Global Corp",
               currency: "pyg",
               account_id: accounts(:depository).id,
               purchase_order_items_attributes: [
                 { product_id: @product.id, quantity: 5, unit_cost: 10 }
               ]
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "draft", json_response["status"]
    assert_equal "Global Corp", json_response["supplier_name"]
  end

  test "should receive purchase order and increase product stock" do
    assert_equal 5, @product.reload.stock

    assert_difference -> { ProductStockMovement.count } => 1 do
      post receive_api_v1_purchase_order_url(@purchase_order), headers: api_headers(@write_api_key)
    end

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "received", json_response["status"]

    assert_equal 15, @product.reload.stock
    movement = @product.stock_movements.last
    assert_equal "entrada", movement.reason
    assert_equal 10, movement.quantity_delta
  end

  test "should cancel received purchase order and reverse product stock" do
    @purchase_order.receive!
    assert_equal 15, @product.reload.stock

    assert_difference -> { ProductStockMovement.count } => 1 do
      post cancel_api_v1_purchase_order_url(@purchase_order), headers: api_headers(@write_api_key)
    end

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "cancelled", json_response["status"]

    assert_equal 5, @product.reload.stock
    movement = @product.stock_movements.last
    assert_equal "salida", movement.reason
    assert_equal(-10, movement.quantity_delta)
  end

  test "should destroy draft purchase order" do
    assert_difference -> { PurchaseOrder.count } => -1 do
      delete api_v1_purchase_order_url(@purchase_order), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
