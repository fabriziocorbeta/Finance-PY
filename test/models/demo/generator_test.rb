require "test_helper"

class Demo::GeneratorTest < ActiveSupport::TestCase
  test "create_monitoring_api_key! skips creation in production when APP_DOMAIN is not a demo host" do
    family = Family.create!(name: "Prod Guard Family", currency: "USD", locale: "en", date_format: "%m-%d-%Y")
    family.users.create!(
      email: "prod-guard@example.com",
      password: "Password1!",
      password_confirmation: "Password1!",
      role: :admin
    )

    Rails.env.stubs(:production?).returns(true)

    with_env_overrides("APP_DOMAIN" => "finance.example.com") do
      assert_no_difference -> { ApiKey.where(display_key: ApiKey::DEMO_MONITORING_KEY).count } do
        assert_nil Demo::Generator.new.send(:create_monitoring_api_key!, family)
      end
    end
  end

  test "create_monitoring_api_key! allows creation in production when APP_DOMAIN matches demo host" do
    ApiKey.where(display_key: ApiKey::DEMO_MONITORING_KEY).delete_all
    family = Family.create!(name: "Demo Guard Family", currency: "USD", locale: "en", date_format: "%m-%d-%Y")
    family.users.create!(
      email: "demo-guard@example.com",
      password: "Password1!",
      password_confirmation: "Password1!",
      role: :admin
    )

    Rails.application.stubs(:config_for).with(:demo).returns({ "hosts" => [ "demo.example.com" ] })
    Rails.env.stubs(:production?).returns(true)

    with_env_overrides("APP_DOMAIN" => "demo.example.com") do
      assert_difference -> { ApiKey.where(display_key: ApiKey::DEMO_MONITORING_KEY).count }, 1 do
        Demo::Generator.new.send(:create_monitoring_api_key!, family)
      end
    end
  end
end
