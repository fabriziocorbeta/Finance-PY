class VectorStore::Registry
  ADAPTERS = {
    openai: "VectorStore::Openai",
    pgvector: "VectorStore::Pgvector",
    qdrant: "VectorStore::Qdrant"
  }.freeze

  OPENAI_HOST = "api.openai.com"

  class << self
    # Returns the configured adapter instance.
    # Reads from VECTOR_STORE_PROVIDER env var, falling back to :openai
    # when OpenAI credentials are present and point at OpenAI itself.
    def adapter
      name = adapter_name
      return nil unless name

      build_adapter(name)
    end

    def configured?
      adapter.present?
    end

    def adapter_name
      explicit = ENV["VECTOR_STORE_PROVIDER"].presence
      return explicit.to_sym if explicit && ADAPTERS.key?(explicit.to_sym)

      # OpenAI-compatible hosts (NVIDIA, Ollama, ...) share the token but have no /v1/vector_stores API.
      :openai if openai_access_token.present? && openai_host?(openai_uri_base)
    end

    private

      def build_adapter(name)
        klass = ADAPTERS[name]&.safe_constantize
        raise VectorStore::ConfigurationError, "Unknown vector store adapter: #{name}" unless klass

        case name
        when :openai   then build_openai
        when :pgvector then build_pgvector
        when :qdrant   then build_qdrant
        else raise VectorStore::ConfigurationError, "No builder defined for adapter: #{name}"
        end
      end

      def build_openai
        token = openai_access_token
        return nil unless token.present?

        VectorStore::Openai.new(
          access_token: token,
          uri_base: openai_uri_base
        )
      end

      def build_pgvector
        VectorStore::Pgvector.new
      end

      def build_qdrant
        url  = ENV.fetch("QDRANT_URL", "http://localhost:6333")
        api_key = ENV["QDRANT_API_KEY"].presence

        VectorStore::Qdrant.new(url: url, api_key: api_key)
      end

      def openai_access_token
        ENV["OPENAI_ACCESS_TOKEN"].presence || Setting.openai_access_token
      end

      def openai_uri_base
        ENV["OPENAI_URI_BASE"].presence || Setting.openai_uri_base.presence
      end

      def openai_host?(uri_base)
        return true if uri_base.blank?

        URI.parse(uri_base.strip).host&.downcase == OPENAI_HOST
      rescue URI::InvalidURIError
        false
      end
  end
end
