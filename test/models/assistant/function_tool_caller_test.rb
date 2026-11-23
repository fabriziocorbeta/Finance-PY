require "test_helper"

class Assistant::FunctionToolCallerTest < ActiveSupport::TestCase
  FakeRequest = Struct.new(:function_name, :function_args, :call_id, keyword_init: true)

  test "raises FunctionExecutionError cleanly when calling an unknown function" do
    caller_instance = Assistant::FunctionToolCaller.new([])
    request = FakeRequest.new(
      function_name: "nonexistent_tool",
      function_args: "{}",
      call_id: "call_123"
    )

    error = assert_raises(Assistant::FunctionToolCaller::FunctionExecutionError) do
      caller_instance.fulfill_requests([ request ])
    end

    assert_includes error.message, "nonexistent_tool"
  end
end
