package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

fun formatDebtAccountType(accountType: String): String = when (accountType) {
    "Loan" -> "Préstamo"
    "CreditCard" -> "Tarjeta de crédito"
    "OtherLiability" -> "Otra deuda"
    else -> accountType
}

@Composable
fun DebtsListScreen(
    viewModel: DebtsListViewModel,
    onAccountClick: (String) -> Unit
) {
    val debts by viewModel.debts.collectAsState()
    val totalsByCurrency by viewModel.totalOwedByCurrency.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (totalsByCurrency.isNotEmpty()) {
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Total adeudado",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            totalsByCurrency.forEach { (currency, cents) ->
                                Text(
                                    text = formatMoney(cents, currency),
                                    style = MaterialTheme.typography.headlineSmall,
                                    color = FinancePyColors.destructive()
                                )
                            }
                        }
                    }
                }
            }

            if (debts.isEmpty()) {
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "No tenés deudas registradas. Las tarjetas de crédito, préstamos y otras obligaciones que agregues como cuenta van a aparecer acá.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
            } else {
                items(debts, key = { it.id }) { debt ->
                    AppCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onAccountClick(debt.id) }
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = debt.name,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                                Text(
                                    text = formatDebtAccountType(debt.accountType),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            Text(
                                text = formatMoney(debt.balanceCents, debt.currency),
                                style = MaterialTheme.typography.titleMedium,
                                color = FinancePyColors.destructive()
                            )
                        }
                    }
                }
            }
        }
    }
}
