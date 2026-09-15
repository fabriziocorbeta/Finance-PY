package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class UpayImportStatusDetailDto(
    val uploaded: Boolean? = null,
    val configured: Boolean? = null,
    val cleaned: Boolean? = null,
    val publishable: Boolean? = null,
    val revertable: Boolean? = null,
    val terminal: Boolean? = null
)

@Serializable
data class UpayImportStatsDto(
    val rows_count: Int = 0,
    val valid_rows_count: Int = 0,
    val invalid_rows_count: Int = 0
)

@Serializable
data class UpayImportResultDto(
    val id: String,
    val type: String,
    val status: String,
    val account_id: String? = null,
    val error: String? = null,
    val status_detail: UpayImportStatusDetailDto? = null,
    val stats: UpayImportStatsDto? = null
)

@Serializable
data class UpayImportResponseDto(
    val data: UpayImportResultDto
)
