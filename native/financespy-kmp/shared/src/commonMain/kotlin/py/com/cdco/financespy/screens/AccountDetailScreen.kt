package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun AccountDetailScreen(viewModel: AccountDetailViewModel) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.account?.let { account ->
            Text(account.name)
            Text("Saldo: ${account.balanceCents / 100.0} ${account.currency}")
            Text("Saldo efectivo: ${account.cashBalanceCents / 100.0} ${account.currency}")
            Text("Tipo: ${account.accountType}${account.subtype?.let { " ($it)" } ?: ""}")
        }
        LazyColumn {
            items(state.entries) { entry ->
                Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
            }
        }
    }
}
