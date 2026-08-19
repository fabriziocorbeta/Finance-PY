package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "accounts")
data class AccountEntity(
    @PrimaryKey val id: String,
    val name: String,
    val balanceCents: Long,
    val cashBalanceCents: Long,
    val currency: String,
    val classification: String,
    val accountType: String,
    val subtype: String?,
    val status: String,
    val updatedAt: String
)
