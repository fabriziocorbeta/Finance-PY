package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class CategoriesResponse(val categories: List<CategoryDto>, val pagination: PaginationDto)

@Serializable
data class CategoryDto(
    val id: String,
    val name: String,
    val color: String,
    val icon: String
)
