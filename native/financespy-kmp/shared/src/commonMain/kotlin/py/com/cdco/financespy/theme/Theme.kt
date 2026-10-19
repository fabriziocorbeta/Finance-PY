package py.com.cdco.financespy.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

val LocalFinancePyColors = staticCompositionLocalOf<FinancePyColors> {
    FinancePyColors
}

val LocalUiVariant = staticCompositionLocalOf<UiVariant> {
    UiVariant.DEFAULT
}

@Immutable
data class FinancePyMetrics(
    val cardCornerRadius: Dp,
    val buttonCornerRadius: Dp,
    val textFieldCornerRadius: Dp,
    val searchFieldCornerRadius: Dp,
    val cardElevation: Dp,
    val cardBorderWidth: Dp,
    val cardPadding: Dp,
    val screenHorizontalPadding: Dp,
    val sectionSpacing: Dp,
    val listItemSpacing: Dp
)

val Material3Metrics = FinancePyMetrics(
    cardCornerRadius = 12.dp,
    buttonCornerRadius = 8.dp,
    textFieldCornerRadius = 6.dp,
    searchFieldCornerRadius = 8.dp,
    cardElevation = 8.dp,
    cardBorderWidth = 1.5.dp,
    cardPadding = 16.dp,
    screenHorizontalPadding = 16.dp,
    sectionSpacing = 16.dp,
    listItemSpacing = 12.dp
)

// Métricas según Apple Human Interface Guidelines (Inset Grouped Lists &
// Controls): radio uniforme de 10pt en celdas agrupadas/botones/buscador,
// elevación 0pt (jerarquía por contraste entre systemGroupedBackground y
// secondarySystemGroupedBackground, sin sombra proyectada) y filas apiladas
// con separador hairline interno (listItemSpacing = 0dp).
val IosHigMetrics = FinancePyMetrics(
    cardCornerRadius = 10.dp,
    buttonCornerRadius = 10.dp,
    textFieldCornerRadius = 10.dp,
    searchFieldCornerRadius = 10.dp,
    cardElevation = 0.dp,
    cardBorderWidth = 0.dp,
    cardPadding = 16.dp,
    screenHorizontalPadding = 16.dp,
    sectionSpacing = 20.dp,
    listItemSpacing = 0.dp
)

val LocalFinancePyMetrics = staticCompositionLocalOf<FinancePyMetrics> {
    Material3Metrics
}

fun metricsForVariant(variant: UiVariant): FinancePyMetrics = when (variant) {
    UiVariant.MATERIAL3 -> Material3Metrics
    UiVariant.IOS -> IosHigMetrics
}

@Composable
fun FinancePyTheme(
    uiVariant: UiVariant = UiVariant.DEFAULT,
    content: @Composable () -> Unit
) {
    val isDark = isSystemInDarkTheme()
    // MaterialTheme's default colorScheme is the M3 light scheme regardless of
    // background: without this, OutlinedTextField's typed-text color
    // (colorScheme.onSurface) stays dark-on-dark against FinancePyColors'
    // black surface, making input text nearly invisible.
    val colorScheme = when (uiVariant) {
        UiVariant.MATERIAL3 -> if (isDark) {
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
        UiVariant.IOS -> if (isDark) {
            darkColorScheme(
                surface = FinancePyColors.IosSecondaryGroupedBgDark,
                background = FinancePyColors.IosSystemGroupedBgDark,
                onSurface = FinancePyColors.White,
                onBackground = FinancePyColors.White,
                onSurfaceVariant = FinancePyColors.IosSecondaryLabelDark,
                outline = FinancePyColors.IosSeparatorDark,
                primary = FinancePyColors.IosBlueDark,
                onPrimary = FinancePyColors.White
            )
        } else {
            lightColorScheme(
                surface = FinancePyColors.IosSecondaryGroupedBgLight,
                background = FinancePyColors.IosSystemGroupedBgLight,
                onSurface = Color(0xFF000000),
                onBackground = Color(0xFF000000),
                onSurfaceVariant = FinancePyColors.IosSecondaryLabelLight,
                outline = FinancePyColors.IosSeparatorLight,
                primary = FinancePyColors.IosBlueLight,
                onPrimary = FinancePyColors.White
            )
        }
    }

    val typography = when (uiVariant) {
        UiVariant.MATERIAL3 -> FinancePyTypography
        UiVariant.IOS -> IosHigTypography
    }

    val metrics = metricsForVariant(uiVariant)

    CompositionLocalProvider(
        LocalUiVariant provides uiVariant,
        LocalFinancePyColors provides FinancePyColors,
        LocalFinancePyMetrics provides metrics
    ) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = typography,
            content = content
        )
    }
}
