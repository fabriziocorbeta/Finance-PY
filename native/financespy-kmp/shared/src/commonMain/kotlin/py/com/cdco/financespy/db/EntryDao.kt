package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EntryDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entries: List<EntryEntity>)

    @Query("DELETE FROM entries WHERE id NOT IN (:ids) AND date >= :sinceDate")
    suspend fun deleteStaleWithinWindow(ids: List<String>, sinceDate: String)

    @Query("SELECT * FROM entries ORDER BY date DESC LIMIT :limit")
    fun observeRecent(limit: Int): Flow<List<EntryEntity>>

    @Query("SELECT * FROM entries ORDER BY date DESC")
    fun observeAll(): Flow<List<EntryEntity>>

    @Query("SELECT * FROM entries WHERE accountId = :accountId ORDER BY date DESC")
    fun observeByAccountId(accountId: String): Flow<List<EntryEntity>>
}
