module Internal
  class VersionsController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false
    skip_authentication

    before_action :authenticate_internal_token!

    def show
      sha = current_commit_sha
      render json: {
        commit_sha: sha,
        version: Sure.version.to_s
      }, status: :ok
    end

    private

      def authenticate_internal_token!
        expected = ENV["INTERNAL_VERSION_TOKEN"]

        if expected.blank?
          render json: { error: "Internal version token not configured" }, status: :service_unavailable
          return
        end

        token = request.headers["X-Internal-Token"].presence ||
                request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

        unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
          render json: { error: "unauthorized" }, status: :unauthorized
        end
      end

      def current_commit_sha
        ENV["BUILD_COMMIT_SHA"].presence ||
          Sure.commit_sha.presence ||
          read_git_head
      end

      def read_git_head
        git_dir = Rails.root.join(".git")
        head_file = git_dir.join("HEAD")

        if File.exist?(head_file)
          head_content = File.read(head_file).strip
          if head_content.start_with?("ref: ")
            ref_path = head_content.delete_prefix("ref: ").strip
            full_ref_path = git_dir.join(ref_path)
            File.exist?(full_ref_path) ? File.read(full_ref_path).strip : nil
          else
            head_content
          end
        else
          `git rev-parse HEAD 2>/dev/null`.strip.presence
        end
      rescue => e
        nil
      end
  end
end
