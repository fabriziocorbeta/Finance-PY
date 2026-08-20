package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "rule_runs")
data class RuleRunEntity(
    @PrimaryKey val id: String,
    val ruleId: String,
    val status: String,
    val executionType: String,
    val executedAt: String
)
