# frozen_string_literal: true

require "test_helper"

class Api::V1::ProductsControllerTest < ActionDispatch::IntegrationTest
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
      name: "Test Product",
      sku: "PROD-001",
      buy_price: 10,
      sell_price: 20,
      currency: "pyg",
      stock: 5,
      min_stock: 2
    )
  end

  test "should list products when business mode is enabled" do
    get api_v1_products_url, headers: api_headers(@read_api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |p| p["id"] == @product.id }
  end

  test "should return forbidden when business mode is disabled" do
    @family.update!(business_mode_enabled: false)

    get api_v1_products_url, headers: api_headers(@read_api_key)
    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal "business_mode_disabled", json_response["error"]
  end

  test "should show product" do
    get api_v1_product_url(@product), headers: api_headers(@read_api_key)
    assert_response :success

    json_response = JSON.parse(response.body)["data"]
    assert_equal @product.id, json_response["id"]
    assert_equal "Test Product", json_response["name"]
    assert_equal "PROD-001", json_response["sku"]
    assert_equal 5, json_response["stock"]
  end

  test "should create product with initial stock movement" do
    assert_difference -> { Product.count } => 1, -> { ProductStockMovement.count } => 1 do
      post api_v1_products_url,
           params: {
             product: {
               name: "New Product",
               sku: "PROD-002",
               buy_price: 15,
               sell_price: 30,
               currency: "pyg",
               initial_stock: 10,
               min_stock: 3
             }
           },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal "New Product", json_response["name"]
    assert_equal 10, json_response["stock"]

    new_prod = Product.find(json_response["id"])
    assert_equal 10, new_prod.stock
    movement = new_prod.stock_movements.last
    assert_equal "entrada", movement.reason
    assert_equal 10, movement.quantity_delta
  end

  test "should update product attributes without directly modifying stock" do
    patch api_v1_product_url(@product),
          params: {
            product: {
              name: "Updated Product Name",
              sell_price: 25,
              stock: 999 # Should be ignored
            }
          },
          headers: api_headers(@write_api_key)

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "Updated Product Name", json_response["name"]

    @product.reload
    assert_equal "Updated Product Name", @product.name
    assert_equal 25, @product.sell_price.to_i
    assert_equal 5, @product.stock # stock remains unchanged
  end

  test "should destroy product" do
    assert_difference -> { Product.count } => -1 do
      delete api_v1_product_url(@product), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
