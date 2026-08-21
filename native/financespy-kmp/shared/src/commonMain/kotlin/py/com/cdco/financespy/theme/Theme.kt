package py.com.cdco.financespy.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

val LocalFinancePyColors = staticCompositionLocalOf<FinancePyColors> {
    FinancePyColors
}

@Composable
fun FinancePyTheme(content: @Composable () -> Unit) {
    CompositionLocalProvider(
        LocalFinancePyColors provides FinancePyColors
    ) {
        MaterialTheme(
            typography = FinancePyTypography,
            content = content
        )
    }
}
