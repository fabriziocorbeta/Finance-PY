package py.com.cdco.financespy.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

object FinancePyColors {
    // Gray scale (Material 3 / Geist palette)
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

    // Apple HIG system palette (iOS variant)
    val IosSystemGroupedBgLight = Color(0xFFF2F2F7)
    val IosSystemGroupedBgDark = Color(0xFF000000)
    val IosSecondaryGroupedBgLight = Color(0xFFFFFFFF)
    val IosSecondaryGroupedBgDark = Color(0xFF1C1C1E)
    val IosTertiaryGroupedBgLight = Color(0xFFE5E5EA)
    val IosTertiaryGroupedBgDark = Color(0xFF2C2C2E)
    val IosQuaternaryFillLight = Color(0xFFD1D1D6)
    val IosQuaternaryFillDark = Color(0xFF3A3A3C)
    val IosBlueLight = Color(0xFF007AFF)
    val IosBlueDark = Color(0xFF0A84FF)
    val IosGreenLight = Color(0xFF34C759)
    val IosGreenDark = Color(0xFF30D158)
    val IosOrangeLight = Color(0xFFFF9500)
    val IosOrangeDark = Color(0xFFFF9F0A)
    val IosRedLight = Color(0xFFFF3B30)
    val IosRedDark = Color(0xFFFF453A)
    val IosSecondaryLabelLight = Color(0xFF6C6C70)
    val IosSecondaryLabelDark = Color(0xFF8E8E93)
    val IosTertiaryLabelLight = Color(0xFF8E8E93)
    val IosTertiaryLabelDark = Color(0xFF636366)
    val IosSeparatorLight = Color(0xFFC6C6C8)
    val IosSeparatorDark = Color(0xFF38383A)

    // Semantic tokens resolved by active UiVariant
    @Composable
    fun surface(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Black else Gray50
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosSystemGroupedBgDark else IosSystemGroupedBgLight
    }

    @Composable
    fun container(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Gray900 else White
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosSecondaryGroupedBgDark else IosSecondaryGroupedBgLight
    }

    @Composable
    fun containerHover(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Gray800 else Gray50
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosTertiaryGroupedBgDark else IosTertiaryGroupedBgLight
    }

    @Composable
    fun textPrimary(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) White else Gray900
        UiVariant.IOS -> if (isSystemInDarkTheme()) White else Color(0xFF000000)
    }

    @Composable
    fun textSecondary(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Gray300 else Gray500
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosSecondaryLabelDark else IosSecondaryLabelLight
    }

    @Composable
    fun textSubdued(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Gray500 else Gray400
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosTertiaryLabelDark else IosTertiaryLabelLight
    }

    @Composable
    fun borderPrimary(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) White.copy(alpha = 0.20f) else Black.copy(alpha = 0.15f)
        UiVariant.IOS -> if (isSystemInDarkTheme()) Color(0xFF545458).copy(alpha = 0.65f) else Color(0xFF3C3C43).copy(alpha = 0.29f)
    }

    @Composable
    fun borderSecondary(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) White.copy(alpha = 0.15f) else Black.copy(alpha = 0.10f)
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosSeparatorDark else IosSeparatorLight
    }

    @Composable
    fun success(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Color(0xFF12B76A) else Color(0xFF10A861)
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosGreenDark else IosGreenLight
    }

    @Composable
    fun warning(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Color(0xFFFDB022) else Color(0xFFDC6803)
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosOrangeDark else IosOrangeLight
    }

    @Composable
    fun destructive(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Color(0xFFED4E4E) else Color(0xFFEC2222)
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosRedDark else IosRedLight
    }

    @Composable
    fun buttonBgPrimary(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) White else Gray900
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosBlueDark else IosBlueLight
    }

    @Composable
    fun buttonBgSecondary(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Gray700 else Gray50
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosTertiaryGroupedBgDark else IosTertiaryGroupedBgLight
    }

    @Composable
    fun buttonBgSecondaryStrong(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Gray700 else Gray200
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosQuaternaryFillDark else IosQuaternaryFillLight
    }

    @Composable
    fun buttonBgGhost(): Color = Color.Transparent

    @Composable
    fun buttonBgDestructive(): Color = when (LocalUiVariant.current) {
        UiVariant.MATERIAL3 -> if (isSystemInDarkTheme()) Color(0xFFED4E4E) else Color(0xFFF13636)
        UiVariant.IOS -> if (isSystemInDarkTheme()) IosRedDark else IosRedLight
    }
}
