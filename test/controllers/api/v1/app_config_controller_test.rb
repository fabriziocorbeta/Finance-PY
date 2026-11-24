# frozen_string_literal: true

require "test_helper"

class Api::V1::AppConfigControllerTest < ActionDispatch::IntegrationTest
  test "returns public mobile version config without authentication" do
    with_env_overrides(
      MOBILE_MIN_SUPPORTED_VERSION: "0.2.0",
      MOBILE_LATEST_VERSION: "0.3.0",
      MOBILE_MIN_ANDROID_VERSION_CODE: "5",
      MOBILE_LATEST_ANDROID_VERSION_CODE: "7",
      MOBILE_MIN_IOS_BUILD: "2",
      MOBILE_LATEST_IOS_BUILD: "4",
      MOBILE_ANDROID_STORE_URL: "https://play.google.com/store/apps/details?id=py.com.cdco.financespy",
      MOBILE_IOS_STORE_URL: "https://apps.apple.com/app/id123456789",
      MOBILE_DIRECT_APK_URL: "https://finance.cd-co.com.py/downloads/financepy-latest.apk",
      MOBILE_FORCE_UPDATE: "false",
      MOBILE_RELEASE_NOTES: "Correcciones PYG y seguridad"
    ) do
      get "/api/v1/app_config"
      assert_response :ok

      body = JSON.parse(response.body)
      assert_equal "0.2.0", body["min_supported_version"]
      assert_equal "0.3.0", body["latest_version"]
      assert_equal 5, body.dig("min_build", "android")
      assert_equal 7, body.dig("latest_build", "android")
      assert_equal 2, body.dig("min_build", "ios")
      assert_equal 4, body.dig("latest_build", "ios")
      assert_equal "https://play.google.com/store/apps/details?id=py.com.cdco.financespy", body["android_store_url"]
      assert_equal "https://apps.apple.com/app/id123456789", body["ios_store_url"]
      assert_equal "https://finance.cd-co.com.py/downloads/financepy-latest.apk", body["direct_apk_url"]
      assert_equal false, body["force_update"]
      assert_equal "Correcciones PYG y seguridad", body["release_notes"]
      assert body["checked_at"].present?
    end
  end

  test "sets force_update true when client build header is below min_build" do
    with_env_overrides(
      MOBILE_MIN_ANDROID_VERSION_CODE: "6",
      MOBILE_LATEST_ANDROID_VERSION_CODE: "7",
      MOBILE_FORCE_UPDATE: "false"
    ) do
      get "/api/v1/app_config", headers: { "X-Platform" => "android", "X-App-Build" => "5" }
      assert_response :ok
      assert_equal true, JSON.parse(response.body)["force_update"]

      get "/api/v1/app_config", headers: { "X-Platform" => "android", "X-App-Build" => "6" }
      assert_response :ok
      assert_equal false, JSON.parse(response.body)["force_update"]
    end
  end

  test "sets force_update true when global MOBILE_FORCE_UPDATE is enabled" do
    with_env_overrides(MOBILE_FORCE_UPDATE: "true") do
      get "/api/v1/app_config"
      assert_response :ok
      assert_equal true, JSON.parse(response.body)["force_update"]
    end
  end
end
