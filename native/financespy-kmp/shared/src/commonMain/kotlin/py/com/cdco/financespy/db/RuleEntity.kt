package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "rules")
data class RuleEntity(
    @PrimaryKey val id: String,
    val name: String?,
    val resourceType: String,
    val active: Boolean,
    val conditionType: String,
    val conditionOperator: String,
    val conditionValue: String,
    val actionType: String,
    val actionValue: String,
    val updatedAt: String
)
