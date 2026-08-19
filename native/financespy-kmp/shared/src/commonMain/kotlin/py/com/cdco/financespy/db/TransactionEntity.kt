package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "transactions")
data class TransactionEntity(
    @PrimaryKey val id: String,
    val categoryId: String?,
    val categoryName: String?,
    val merchantId: String?,
    val merchantName: String?,
    val kind: String
)
