package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "budgets")
data class BudgetEntity(
    @PrimaryKey val id: String,
    val startDate: String,
    val endDate: String,
    val budgetedSpending: Double,
    val expectedIncome: Double,
    val currency: String,
    val actualSpending: Double,
    val actualSpendingCents: Long,
    val allocatedSpending: Double,
    val allocatedSpendingCents: Long,
    val availableToSpend: Double,
    val availableToSpendCents: Long,
    val percentOfBudgetSpent: Double,
    val actualIncome: Double,
    val actualIncomeCents: Long,
    val remainingExpectedIncome: Double,
    val remainingExpectedIncomeCents: Long
)
