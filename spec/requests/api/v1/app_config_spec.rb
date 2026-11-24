# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API V1 App Config', type: :request do
  path '/api/v1/app_config' do
    get 'Retrieve mobile app version and update policy' do
      description 'Public, cacheable endpoint returning minimum supported and latest mobile versions, store URLs, direct APK URL, and force-update flag.'
      tags 'App Config'
      produces 'application/json'

      parameter name: :'X-Platform', in: :header, type: :string, required: false, description: 'Client platform (android or ios)'
      parameter name: :'X-App-Version', in: :header, type: :string, required: false, description: 'Client semantic version (e.g. 0.2.0)'
      parameter name: :'X-App-Build', in: :header, type: :string, required: false, description: 'Client integer build number (versionCode / CFBundleVersion)'

      response '200', 'app config retrieved' do
        schema type: :object,
               properties: {
                 min_supported_version: { type: :string },
                 latest_version: { type: :string },
                 min_build: {
                   type: :object,
                   properties: {
                     android: { type: :integer },
                     ios: { type: :integer }
                   },
                   required: %w[android ios]
                 },
                 latest_build: {
                   type: :object,
                   properties: {
                     android: { type: :integer },
                     ios: { type: :integer }
                   },
                   required: %w[android ios]
                 },
                 android_store_url: { type: :string, nullable: true },
                 ios_store_url: { type: :string, nullable: true },
                 direct_apk_url: { type: :string, nullable: true },
                 force_update: { type: :boolean },
                 release_notes: { type: :string, nullable: true },
                 checked_at: { type: :string, format: :'date-time' }
               },
               required: %w[min_supported_version latest_version min_build latest_build force_update checked_at]

        run_test!
      end
    end
  end
end
