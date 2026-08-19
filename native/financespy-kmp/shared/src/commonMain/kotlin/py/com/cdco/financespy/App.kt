package py.com.cdco.financespy

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.LoginScreen

@Composable
fun App(
    isLoggedIn: Boolean?,
    onLoginClick: () -> Unit,
    dashboardViewModelFactory: () -> DashboardViewModel
) {
    MaterialTheme {
        when (isLoggedIn) {
            null -> {}
            false -> LoginScreen(onLoginClick = onLoginClick)
            true -> DashboardScreen(viewModel = remember { dashboardViewModelFactory() })
        }
    }
}
