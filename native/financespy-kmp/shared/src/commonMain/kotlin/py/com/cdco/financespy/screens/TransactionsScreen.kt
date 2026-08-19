package py.com.cdco.financespy.screens

import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue

@Composable
fun TransactionsScreen(viewModel: TransactionsViewModel) {
    val entries by viewModel.entries.collectAsState()

    LazyColumn {
        items(entries) { entry ->
            Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
        }
    }
}
