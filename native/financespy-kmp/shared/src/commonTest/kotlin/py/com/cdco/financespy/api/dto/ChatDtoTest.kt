package py.com.cdco.financespy.api.dto

import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ChatDtoTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun testMessageDtoWithToolCallsObject() {
        // Tool arguments and results are jsonb objects/arrays
        val jsonString = """
            {
                "id": "msg1",
                "type": "assistant_message",
                "role": "assistant",
                "content": null,
                "tool_calls": [
                    {
                        "id": "tool1",
                        "function_name": "get_weather",
                        "function_arguments": {"location": "Asuncion"},
                        "function_result": {"temp": 30, "unit": "C"},
                        "created_at": "2024-01-01T12:00:00Z"
                    }
                ]
            }
        """.trimIndent()

        val message = json.decodeFromString<MessageDto>(jsonString)
        assertEquals("msg1", message.id)
        assertNotNull(message.tool_calls)
        assertEquals(1, message.tool_calls?.size)
        val toolCall = message.tool_calls!![0]
        assertEquals("get_weather", toolCall.function_name)
        assertNotNull(toolCall.function_arguments)
        assertTrue(toolCall.function_arguments.toString().contains("Asuncion"))
        assertNotNull(toolCall.function_result)
        assertTrue(toolCall.function_result.toString().contains("30"))
    }

    @Test
    fun testMessageRetryResponseDtoDeserialization() {
        val jsonString = """
            {
                "message": "Retry initiated",
                "message_id": "msg_retry_123"
            }
        """.trimIndent()

        val response = json.decodeFromString<MessageRetryResponseDto>(jsonString)
        assertEquals("Retry initiated", response.message)
        assertEquals("msg_retry_123", response.message_id)
    }
}
