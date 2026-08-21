package py.com.cdco.financespy.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object FinancePyColors {
    // Gray scale
    val Gray50 = Color(0xFFF7F7F7)
    val Gray100 = Color(0xFFF0F0F0)
    val Gray200 = Color(0xFFE7E7E7)
    val Gray300 = Color(0xFFCFCFCF)
    val Gray400 = Color(0xFF9E9E9E)
    val Gray500 = Color(0xFF737373)
    val Gray600 = Color(0xFF5C5C5C)
    val Gray700 = Color(0xFF363636)
    val Gray800 = Color(0xFF242424)
    val Gray900 = Color(0xFF171717)
    val White = Color(0xFFFFFFFF)
    val Black = Color(0xFF0B0B0B)

    // Semantic tokens
    @Composable
    fun surface(): Color = if (isSystemInDarkTheme()) Black else Gray50

    @Composable
    fun container(): Color = if (isSystemInDarkTheme()) Gray900 else White

    @Composable
    fun containerHover(): Color = if (isSystemInDarkTheme()) Gray800 else Gray50

    @Composable
    fun textPrimary(): Color = if (isSystemInDarkTheme()) White else Gray900

    @Composable
    fun textSecondary(): Color = if (isSystemInDarkTheme()) Gray300 else Gray500

    @Composable
    fun textSubdued(): Color = if (isSystemInDarkTheme()) Gray500 else Gray400

    @Composable
    fun borderPrimary(): Color = if (isSystemInDarkTheme()) White.copy(alpha = 0.20f) else Black.copy(alpha = 0.15f)

    @Composable
    fun borderSecondary(): Color = if (isSystemInDarkTheme()) White.copy(alpha = 0.15f) else Black.copy(alpha = 0.10f)

    @Composable
    fun success(): Color = if (isSystemInDarkTheme()) Color(0xFF12B76A) else Color(0xFF10A861)

    @Composable
    fun warning(): Color = if (isSystemInDarkTheme()) Color(0xFFFDB022) else Color(0xFFDC6803)

    @Composable
    fun destructive(): Color = if (isSystemInDarkTheme()) Color(0xFFED4E4E) else Color(0xFFEC2222)

    @Composable
    fun buttonBgPrimary(): Color = if (isSystemInDarkTheme()) White else Gray900

    @Composable
    fun buttonBgSecondary(): Color = if (isSystemInDarkTheme()) Gray700 else Gray50

    @Composable
    fun buttonBgSecondaryStrong(): Color = if (isSystemInDarkTheme()) Gray700 else Gray200

    @Composable
    fun buttonBgGhost(): Color = Color.Transparent

    @Composable
    fun buttonBgDestructive(): Color = if (isSystemInDarkTheme()) Color(0xFFED4E4E) else Color(0xFFF13636)
}
