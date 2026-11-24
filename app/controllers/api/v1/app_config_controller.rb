# frozen_string_literal: true

module Api
  module V1
    # Lightweight public endpoint returning minimum supported and latest mobile app
    # versions + store/APK update URLs. Unauthenticated on purpose so logged-out
    # users or broken legacy clients still receive update prompts.
    class AppConfigController < BaseController
      skip_before_action :authenticate_request!
      skip_before_action :check_api_key_rate_limit
      skip_before_action :log_api_access
      skip_around_action :switch_api_timezone_and_locale

      def show
        expires_in 5.minutes, public: true

        min_android_build = env_int("MOBILE_MIN_ANDROID_VERSION_CODE", 5)
        latest_android_build = [ env_int("MOBILE_LATEST_ANDROID_VERSION_CODE", min_android_build), min_android_build ].max
        min_ios_build = env_int("MOBILE_MIN_IOS_BUILD", 1)
        latest_ios_build = [ env_int("MOBILE_LATEST_IOS_BUILD", min_ios_build), min_ios_build ].max

        min_supported_version = ENV.fetch("MOBILE_MIN_SUPPORTED_VERSION", "0.2.0").presence || "0.2.0"
        latest_version = ENV.fetch("MOBILE_LATEST_VERSION", min_supported_version).presence || min_supported_version

        global_force = ActiveModel::Type::Boolean.new.cast(ENV.fetch("MOBILE_FORCE_UPDATE", "false"))
        client_force = client_below_minimum?(min_android_build: min_android_build, min_ios_build: min_ios_build)

        render json: {
          min_supported_version: min_supported_version,
          latest_version: latest_version,
          min_build: {
            android: min_android_build,
            ios: min_ios_build
          },
          latest_build: {
            android: latest_android_build,
            ios: latest_ios_build
          },
          android_store_url: ENV["MOBILE_ANDROID_STORE_URL"].presence,
          ios_store_url: ENV["MOBILE_IOS_STORE_URL"].presence,
          direct_apk_url: ENV["MOBILE_DIRECT_APK_URL"].presence,
          force_update: global_force || client_force,
          release_notes: ENV["MOBILE_RELEASE_NOTES"].presence,
          checked_at: Time.current.iso8601
        }, status: :ok
      end

      private

        def env_int(key, default_value)
          raw = ENV[key].to_s.strip
          return default_value if raw.blank?

          parsed = Integer(raw, 10)
          parsed.positive? ? parsed : default_value
        rescue ArgumentError
          default_value
        end

        def client_below_minimum?(min_android_build:, min_ios_build:)
          platform = (params[:platform].presence || request.headers["X-Platform"].presence).to_s.downcase
          raw_build = params[:build].presence || request.headers["X-App-Build"].presence
          return false if platform.blank? || raw_build.blank?

          build_num = Integer(raw_build.to_s.strip, 10)
          case platform
          when "android" then build_num < min_android_build
          when "ios" then build_num < min_ios_build
          else false
          end
        rescue ArgumentError
          false
        end
    end
  end
end
