package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "receivables")
data class ReceivableEntity(
    @PrimaryKey val id: String,
    val name: String,
    val totalAmount: Double,
    val balance: Double,
    val balanceCents: Long,
    val originalBalance: Double,
    val originalBalanceCents: Long,
    val paidAmount: Double,
    val paidAmountCents: Long,
    val percentPaid: Double,
    val installmentCount: Int?,
    val dueDay: Int?,
    val currency: String,
    val notes: String?,
    val updatedAt: String
)
