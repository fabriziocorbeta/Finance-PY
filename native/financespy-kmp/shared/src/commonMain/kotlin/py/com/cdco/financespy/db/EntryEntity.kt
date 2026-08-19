package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "entries")
data class EntryEntity(
    @PrimaryKey val id: String,
    val accountId: String,
    val date: String,
    val name: String,
    val amountCents: Long,
    val currency: String,
    val entryableType: String,
    val entryableId: String,
    val parentEntryId: String?,
    val transferId: String?,
    val updatedAt: String
)
