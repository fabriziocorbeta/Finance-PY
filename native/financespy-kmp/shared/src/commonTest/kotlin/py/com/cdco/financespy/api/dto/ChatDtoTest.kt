package py.com.cdco.financespy.api.dto

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ChatDtoTest {

    private val jsonParser = Json { ignoreUnknownKeys = true }

    @Test
    fun testParseChatResponse() {
        val json = """
        {
          "id": "chat_123",
          "title": "New Chat",
          "error": null,
          "created_at": "2024-03-24T10:00:00Z",
          "updated_at": "2024-03-24T10:00:00Z",
          "messages": [
            {
              "id": "msg_1",
              "type": "user_message",
              "role": "user",
              "content": "Hello AI",
              "created_at": "2024-03-24T10:00:00Z",
              "updated_at": "2024-03-24T10:00:00Z",
              "ai_response_status": "pending",
              "ai_response_message": "AI response is being generated"
            },
            {
              "id": "msg_2",
              "type": "assistant_message",
              "role": "assistant",
              "content": "Hi there! How can I help?",
              "model": "gpt-4",
              "created_at": "2024-03-24T10:00:05Z",
              "updated_at": "2024-03-24T10:00:05Z",
              "tool_calls": [
                {
                  "id": "tool_1",
                  "function_name": "fetch_balance",
                  "function_arguments": "{}",
                  "function_result": "100.0",
                  "created_at": "2024-03-24T10:00:02Z"
                }
              ]
            }
          ],
          "pagination": {
            "page": 1,
            "per_page": 20,
            "total_count": 2,
            "total_pages": 1
          }
        }
        """.trimIndent()

        val parsed = jsonParser.decodeFromString(ChatResponseDto.serializer(), json)

        assertEquals("chat_123", parsed.id)
        assertEquals("New Chat", parsed.title)
        assertNotNull(parsed.messages)
        assertEquals(2, parsed.messages?.size)

        val userMessage = parsed.messages!![0]
        assertEquals("user_message", userMessage.type)
        assertEquals("user", userMessage.role)
        assertEquals("Hello AI", userMessage.content)
        assertEquals("pending", userMessage.ai_response_status)

        val assistantMessage = parsed.messages!![1]
        assertEquals("assistant_message", assistantMessage.type)
        assertEquals("assistant", assistantMessage.role)
        assertEquals("gpt-4", assistantMessage.model)

        val toolCalls = assistantMessage.tool_calls
        assertNotNull(toolCalls)
        assertEquals(1, toolCalls.size)
        assertEquals("fetch_balance", toolCalls[0].function_name)

        assertNotNull(parsed.pagination)
        assertEquals(1, parsed.pagination?.page)
        assertEquals(2, parsed.pagination?.total_count)
    }
}
