package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface RuleDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(rules: List<RuleEntity>)

    @Query("DELETE FROM rules WHERE id NOT IN (:ids)")
    suspend fun deleteAllExcept(ids: List<String>)

    @Query("SELECT * FROM rules ORDER BY name ASC")
    fun observeAll(): Flow<List<RuleEntity>>

    @Query("SELECT * FROM rules WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): RuleEntity?

    @Query("DELETE FROM rules WHERE id = :id")
    suspend fun deleteById(id: String)
}
