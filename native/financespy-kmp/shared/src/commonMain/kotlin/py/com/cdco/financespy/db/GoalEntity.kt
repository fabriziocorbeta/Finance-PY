package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "goals")
data class GoalEntity(
    @PrimaryKey val id: String,
    val name: String,
    val targetAmount: String,
    val currency: String,
    val targetDate: String? = null,
    val color: String? = null,
    val icon: String? = null,
    val notes: String? = null,
    val state: String? = null,
    val progressBasis: String? = null,
    val currentBalance: Double? = null,
    val currentBalanceCents: Long? = null,
    val remainingAmount: Double? = null,
    val remainingAmountCents: Long? = null,
    val progressPercent: Int? = null,
    val updatedAt: String? = null
)
