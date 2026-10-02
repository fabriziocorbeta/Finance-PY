package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

// The backend's import show/create/publish response is generic over every
// Import subtype (TransactionImport, UpayImport, PdfImport, ...) -- same
// shape UpayImportResultDto already models, reused here rather than
// duplicating it.
typealias PdfImportResultDto = UpayImportResultDto

@Serializable
data class PdfImportRowFieldsDto(
    val date: String? = null,
    val amount: String? = null,
    val currency: String? = null,
    val name: String? = null,
    val category: String? = null,
    val notes: String? = null
)

@Serializable
data class PdfImportRowDto(
    val id: String,
    val row_number: Int,
    val valid: Boolean,
    val errors: List<String> = emptyList(),
    val fields: PdfImportRowFieldsDto
)

@Serializable
data class PdfImportRowsResponseDto(
    val data: List<PdfImportRowDto>
)
