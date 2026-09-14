package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class FamilyExportFileDto(
    val attached: Boolean = false,
    val byte_size: Long? = null,
    val content_type: String? = null
)

@Serializable
data class FamilyExportDto(
    val id: String,
    val status: String,
    val filename: String? = null,
    val downloadable: Boolean = false,
    val download_path: String? = null,
    val file: FamilyExportFileDto? = null,
    val created_at: String,
    val updated_at: String? = null
)

@Serializable
data class FamilyExportEnvelope(
    val data: FamilyExportDto
)

@Serializable
data class FamilyExportMetaDto(
    val page: Int,
    val per_page: Int,
    val total_count: Int,
    val total_pages: Int
)

@Serializable
data class FamilyExportsEnvelope(
    val data: List<FamilyExportDto>,
    val meta: FamilyExportMetaDto? = null
)
