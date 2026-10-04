package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class ToolCallDto(
    val id: String,
    val function_name: String?,
    val function_arguments: String?,
    val function_result: String?,
    val created_at: String?
)

@Serializable
data class MessageDto(
    val id: String,
    val chat_id: String? = null,
    val type: String?,
    val role: String,
    val content: String?,
    val model: String? = null,
    val created_at: String?,
    val updated_at: String?,
    val ai_response_status: String? = null,
    val ai_response_message: String? = null,
    val tool_calls: List<ToolCallDto>? = null
)

@Serializable
data class ChatDto(
    val id: String,
    val title: String?,
    val error: String?,
    val created_at: String?,
    val updated_at: String?,
    val last_message_at: String? = null,
    val message_count: Int? = null
)

@Serializable
data class ChatResponseDto(
    val id: String,
    val title: String?,
    val error: String?,
    val created_at: String?,
    val updated_at: String?,
    val messages: List<MessageDto>? = null,
    val pagination: PaginationDto? = null
)

@Serializable
data class ChatsListResponseDto(
    val chats: List<ChatDto>,
    val pagination: PaginationDto
)
