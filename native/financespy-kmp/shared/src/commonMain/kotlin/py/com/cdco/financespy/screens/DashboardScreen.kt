package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.components.AppButton

@Composable
fun DashboardScreen(viewModel: DashboardViewModel, onAccountClick: (String) -> Unit) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.balanceSheet?.let { bs ->
            Text("Patrimonio neto: ${bs.net_worth.cents ?: bs.net_worth.amount} ${bs.currency}")
        }
        AppButton(text = "Actualizar", onClick = { viewModel.refresh() })
        if (state.isSyncing) CircularProgressIndicator()
        state.syncError?.let { Text("Error: $it") }

        Text("Cuentas")
        LazyColumn {
            items(state.accounts) { account ->
                Text(
                    "${account.name}: ${account.balanceCents / 100.0} ${account.currency}",
                    modifier = Modifier.fillMaxWidth().clickable { onAccountClick(account.id) }
                )
            }
        }

        Text("Transacciones recientes")
        LazyColumn {
            items(state.recentEntries) { entry ->
                Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
            }
        }
    }
}
