package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface ReceivableDao {
    @Query("SELECT * FROM receivables ORDER BY name ASC")
    fun observeAll(): Flow<List<ReceivableEntity>>

    @Query("SELECT * FROM receivables WHERE id = :id")
    fun observeById(id: String): Flow<ReceivableEntity?>

    @Query("SELECT * FROM receivables WHERE id = :id")
    suspend fun getById(id: String): ReceivableEntity?

    @Upsert
    suspend fun upsertAll(receivables: List<ReceivableEntity>)

    @Upsert
    suspend fun upsert(receivable: ReceivableEntity)

    @Query("DELETE FROM receivables WHERE id NOT IN (:ids)")
    suspend fun deleteAllExcept(ids: List<String>)

    @Query("DELETE FROM receivables WHERE id = :id")
    suspend fun deleteById(id: String)
}
