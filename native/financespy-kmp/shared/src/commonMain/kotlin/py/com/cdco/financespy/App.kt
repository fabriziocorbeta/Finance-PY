package py.com.cdco.financespy

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.LoginScreen
import py.com.cdco.financespy.screens.TransactionsScreen
import py.com.cdco.financespy.screens.TransactionsViewModel

@Composable
fun App(
    isLoggedIn: Boolean?,
    onLoginClick: () -> Unit,
    dashboardViewModelFactory: () -> DashboardViewModel,
    transactionsViewModelFactory: () -> TransactionsViewModel
) {
    MaterialTheme {
        when (isLoggedIn) {
            null -> {}
            false -> LoginScreen(onLoginClick = onLoginClick)
            true -> {
                var selectedTab by remember { mutableStateOf(0) }
                Column {
                    TabRow(selectedTabIndex = selectedTab) {
                        Tab(selected = selectedTab == 0, onClick = { selectedTab = 0 }, text = { Text("Dashboard") })
                        Tab(selected = selectedTab == 1, onClick = { selectedTab = 1 }, text = { Text("Transacciones") })
                    }
                    when (selectedTab) {
                        0 -> DashboardScreen(viewModel = remember { dashboardViewModelFactory() })
                        1 -> TransactionsScreen(viewModel = remember { transactionsViewModelFactory() })
                    }
                }
            }
        }
    }
}
