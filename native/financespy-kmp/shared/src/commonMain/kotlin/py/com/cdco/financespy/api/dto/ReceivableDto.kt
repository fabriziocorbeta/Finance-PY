package py.com.cdco.financespy.api.dto

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull

@OptIn(ExperimentalSerializationApi::class)
object FlexibleDoubleSerializer : KSerializer<Double?> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("FlexibleDouble", PrimitiveKind.DOUBLE)

    override fun deserialize(decoder: Decoder): Double? {
        return when (decoder) {
            is JsonDecoder -> {
                val element = decoder.decodeJsonElement()
                if (element is JsonPrimitive) {
                    element.doubleOrNull ?: element.content.toDoubleOrNull()
                } else null
            }
            else -> runCatching { decoder.decodeDouble() }.getOrNull()
        }
    }

    override fun serialize(encoder: Encoder, value: Double?) {
        if (value != null) {
            encoder.encodeDouble(value)
        } else {
            encoder.encodeNull()
        }
    }
}

@Serializable
data class ReceivablesEnvelope(
    val data: List<ReceivableDto>,
    val meta: ReceivablesMetaDto? = null
)

@Serializable
data class ReceivableEnvelope(
    val data: ReceivableDto
)

@Serializable
data class ReceivablesMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class ReceivableDto(
    val id: String,
    val name: String? = null,
    @Serializable(with = FlexibleDoubleSerializer::class) val total_amount: Double? = null,
    @Serializable(with = FlexibleDoubleSerializer::class) val balance: Double? = null,
    val balance_cents: Long? = null,
    @Serializable(with = FlexibleDoubleSerializer::class) val original_balance: Double? = null,
    val original_balance_cents: Long? = null,
    @Serializable(with = FlexibleDoubleSerializer::class) val paid_amount: Double? = null,
    val paid_amount_cents: Long? = null,
    @Serializable(with = FlexibleDoubleSerializer::class) val percent_paid: Double? = null,
    val installment_count: Int? = null,
    val due_day: Int? = null,
    val currency: String? = null,
    val notes: String? = null,
    val updated_at: String? = null
)

@Serializable
data class CreateReceivableRequest(
    val receivable: CreateReceivableBody
)

@Serializable
data class CreateReceivableBody(
    val name: String,
    val total_amount: Double,
    val balance: Double? = null,
    val installment_count: Int? = null,
    val due_day: Int? = null,
    val currency: String,
    val notes: String? = null
)

@Serializable
data class UpdateReceivableRequest(
    val receivable: UpdateReceivableBody
)

@Serializable
data class UpdateReceivableBody(
    val name: String? = null,
    val total_amount: Double? = null,
    val balance: Double? = null,
    val installment_count: Int? = null,
    val due_day: Int? = null,
    val currency: String? = null,
    val notes: String? = null
)
