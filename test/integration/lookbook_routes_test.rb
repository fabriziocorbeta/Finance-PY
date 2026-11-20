require "test_helper"

class LookbookRoutesTest < ActionDispatch::IntegrationTest
  test "design-system Lookbook engine is not mounted outside development" do
    assert Rails.application.routes.routes.none? { |route| route.path.spec.to_s.start_with?("/design-system") }

    get "/design-system"
    assert_response :not_found
  end
end
