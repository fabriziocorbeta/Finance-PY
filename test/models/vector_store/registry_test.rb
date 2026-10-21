require "test_helper"

class VectorStore::RegistryTest < ActiveSupport::TestCase
  setup do
    Setting.stubs(:openai_uri_base).returns(nil)
  end

  test "adapter_name defaults to openai when access token present" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil, OPENAI_URI_BASE: nil) do
      assert_equal :openai, VectorStore::Registry.adapter_name
    end
  end

  test "adapter_name defaults to openai when uri base points at api.openai.com" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil, OPENAI_URI_BASE: "https://api.openai.com/v1") do
      assert_equal :openai, VectorStore::Registry.adapter_name
    end
  end

  test "adapter_name returns nil when uri base points at an OpenAI-compatible host" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil, OPENAI_URI_BASE: "https://integrate.api.nvidia.com") do
      assert_nil VectorStore::Registry.adapter_name
      assert_nil VectorStore::Registry.adapter
      assert_not VectorStore.configured?
    end
  end

  test "adapter_name reads uri base from Setting when ENV is blank" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    Setting.stubs(:openai_uri_base).returns("http://localhost:11434/v1")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil, OPENAI_URI_BASE: nil) do
      assert_nil VectorStore::Registry.adapter_name
    end
  end

  test "explicit VECTOR_STORE_PROVIDER wins over a non-OpenAI uri base" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: "pgvector", OPENAI_URI_BASE: "https://integrate.api.nvidia.com") do
      assert_equal :pgvector, VectorStore::Registry.adapter_name
    end
  end

  test "explicit VECTOR_STORE_PROVIDER=openai is honored even with a non-OpenAI uri base" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: "openai", OPENAI_URI_BASE: "https://integrate.api.nvidia.com") do
      assert_equal :openai, VectorStore::Registry.adapter_name
    end
  end

  test "adapter_name returns nil when no credentials configured" do
    VectorStore::Registry.stubs(:openai_access_token).returns(nil)
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil) do
      assert_nil VectorStore::Registry.adapter_name
    end
  end

  test "adapter_name respects explicit VECTOR_STORE_PROVIDER" do
    ClimateControl.modify(VECTOR_STORE_PROVIDER: "qdrant") do
      assert_equal :qdrant, VectorStore::Registry.adapter_name
    end
  end

  test "adapter_name falls back to openai for unknown provider" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: "unknown_store", OPENAI_URI_BASE: nil) do
      assert_equal :openai, VectorStore::Registry.adapter_name
    end
  end

  test "adapter returns VectorStore::Openai instance when openai configured" do
    VectorStore::Registry.stubs(:openai_access_token).returns("sk-test")
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil, OPENAI_URI_BASE: nil) do
      adapter = VectorStore::Registry.adapter
      assert_instance_of VectorStore::Openai, adapter
    end
  end

  test "adapter returns nil when nothing configured" do
    VectorStore::Registry.stubs(:openai_access_token).returns(nil)
    ClimateControl.modify(VECTOR_STORE_PROVIDER: nil) do
      assert_nil VectorStore::Registry.adapter
    end
  end

  test "adapter returns VectorStore::Pgvector instance when pgvector configured" do
    ClimateControl.modify(VECTOR_STORE_PROVIDER: "pgvector") do
      adapter = VectorStore::Registry.adapter
      assert_instance_of VectorStore::Pgvector, adapter
    end
  end

  test "configured? delegates to adapter presence" do
    VectorStore::Registry.stubs(:adapter).returns(nil)
    assert_not VectorStore.configured?

    VectorStore::Registry.stubs(:adapter).returns(VectorStore::Openai.new(access_token: "sk-test"))
    assert VectorStore.configured?
  end
end
