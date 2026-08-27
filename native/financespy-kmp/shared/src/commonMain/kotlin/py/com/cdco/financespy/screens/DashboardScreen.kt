package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun DashboardScreen(viewModel: DashboardViewModel, onAccountClick: (String) -> Unit) {
    val state by viewModel.state.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        state.balanceSheet?.let { bs ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Patrimonio neto",
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary()
                    )
                    Text(
                        text = "${bs.net_worth.cents ?: bs.net_worth.amount} ${bs.currency}",
                        style = MaterialTheme.typography.headlineSmall,
                        color = FinancePyColors.textPrimary(),
                        modifier = Modifier.padding(top = 4.dp)
                    )
                }
            }
        }

        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                AppButton(text = "Actualizar", onClick = { viewModel.refresh() })
                if (state.isSyncing) {
                    CircularProgressIndicator(color = FinancePyColors.textPrimary())
                }
            }
            state.syncError?.let {
                Text(
                    text = "Error: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.destructive(),
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }

        item {
            Text(
                text = "Cuentas",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary(),
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(state.accounts) { account ->
            AppCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onAccountClick(account.id) }
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = account.name,
                        style = MaterialTheme.typography.titleMedium,
                        color = FinancePyColors.textPrimary()
                    )
                    Text(
                        text = "${account.balanceCents / 100.0} ${account.currency}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
        }

        item {
            Text(
                text = "Transacciones recientes",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary(),
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(state.recentEntries) { entry ->
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = entry.name,
                            style = MaterialTheme.typography.titleMedium,
                            color = FinancePyColors.textPrimary()
                        )
                        Text(
                            text = entry.date,
                            style = MaterialTheme.typography.labelMedium,
                            color = FinancePyColors.textSubdued()
                        )
                    }
                    Text(
                        text = "${entry.amountCents / 100.0} ${entry.currency}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
        }
    }
}
