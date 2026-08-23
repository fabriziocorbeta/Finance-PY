package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
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

@Composable
fun AccountDetailScreen(viewModel: AccountDetailViewModel) {
    val state by viewModel.state.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        state.account?.let { account ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = account.name,
                            style = MaterialTheme.typography.titleLarge,
                            color = FinancePyColors.textPrimary()
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Saldo: ${account.balanceCents / 100.0} ${account.currency}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = "Saldo efectivo: ${account.cashBalanceCents / 100.0} ${account.currency}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = "Tipo: ${account.accountType}${account.subtype?.let { " ($it)" } ?: ""}",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSubdued()
                            )
                        }
                    }
                }
            }
        }

        item {
            Text(
                text = "Transacciones",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary(),
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(state.entries) { entry ->
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
