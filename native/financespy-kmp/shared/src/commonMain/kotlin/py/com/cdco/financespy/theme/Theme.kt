package py.com.cdco.financespy.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

val LocalFinancePyColors = staticCompositionLocalOf<FinancePyColors> {
    FinancePyColors
}

@Composable
fun FinancePyTheme(content: @Composable () -> Unit) {
    // MaterialTheme's default colorScheme is the M3 light scheme regardless of
    // background: without this, OutlinedTextField's typed-text color
    // (colorScheme.onSurface) stays dark-on-dark against FinancePyColors'
    // black surface, making input text nearly invisible.
    val colorScheme = if (isSystemInDarkTheme()) {
        darkColorScheme(
            surface = FinancePyColors.Black,
            background = FinancePyColors.Black,
            onSurface = FinancePyColors.White,
            onBackground = FinancePyColors.White,
            onSurfaceVariant = FinancePyColors.Gray300,
            outline = FinancePyColors.Gray500,
            primary = FinancePyColors.White,
            onPrimary = FinancePyColors.Gray900
        )
    } else {
        lightColorScheme(
            surface = FinancePyColors.White,
            background = FinancePyColors.Gray50,
            onSurface = FinancePyColors.Gray900,
            onBackground = FinancePyColors.Gray900,
            onSurfaceVariant = FinancePyColors.Gray500,
            outline = FinancePyColors.Gray400,
            primary = FinancePyColors.Gray900,
            onPrimary = FinancePyColors.White
        )
    }

    CompositionLocalProvider(
        LocalFinancePyColors provides FinancePyColors
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = FinancePyTypography,
            content = content
        )
    }
}
