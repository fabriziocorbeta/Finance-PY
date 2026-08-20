package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface RuleRunDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(ruleRuns: List<RuleRunEntity>)

    @Query("SELECT * FROM rule_runs WHERE ruleId = :ruleId ORDER BY executedAt DESC")
    fun observeByRuleId(ruleId: String): Flow<List<RuleRunEntity>>
}
