package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * iOS 26 Liquid Glass material specification.
 *
 * Implements Apple's iOS 26 Liquid Glass design language:
 * 1. Curvature: Continuous squircle / capsule geometry (default 16.dp for cards, 32.dp for floating dock).
 * 2. Crystalline Substrate: Luminous, high-clarity translucent fill:
 *    - Light mode: Pure crystalline white-tint (alpha 0.58f..0.82f) letting content below shine through.
 *    - Dark mode: Smoky crystalline slate (alpha 0.62f..0.86f).
 * 3. Surface Specular Sheen: A vertical lighting gradient simulating top ambient key light reflecting
 *    off the curved front surface of the lens (Fresnel sheen), with subtle caustic bounce at the bottom rim.
 * 4. Specular Bevel Rim: Directional hairline stroke (1.dp) with sharp specular crest at the top
 *    (alpha 0.95f in light, 0.48f in dark) fading to soft ambient reflection along sides and bottom.
 * 5. Optical Ambient Occlusion: Soft, deep, diffused ambient shadow (12.dp elevation) separating
 *    the floating glass plane from background content.
 */
fun Modifier.iosLiquidGlass(
    shape: Shape = RoundedCornerShape(16.dp),
    contrastBoost: Float = 0f,
    elevation: Dp = 12.dp,
    borderWidth: Dp = 1.dp
): Modifier = composed {
    val isDark = isSystemInDarkTheme()

    // 1. Crystalline translucent substrate
    val baseAlpha = if (isDark) {
        (0.62f + contrastBoost * 0.4f).coerceIn(0.55f, 0.92f)
    } else {
        (0.58f + contrastBoost * 0.4f).coerceIn(0.50f, 0.90f)
    }
    val glassSubstrate = if (isDark) {
        Color(0xFF1C1C20).copy(alpha = baseAlpha)
    } else {
        Color(0xFFFAFBFD).copy(alpha = baseAlpha)
    }

    // 2. Optical surface sheen (simulates the 3D curved front face catching environment light)
    val surfaceSheen = Brush.verticalGradient(
        if (isDark) {
            listOf(
                Color.White.copy(alpha = 0.16f),
                Color.White.copy(alpha = 0.03f),
                Color.Transparent,
                Color.White.copy(alpha = 0.05f)
            )
        } else {
            listOf(
                Color.White.copy(alpha = 0.42f),
                Color.White.copy(alpha = 0.08f),
                Color.Transparent,
                Color.White.copy(alpha = 0.16f)
            )
        }
    )

    // 3. Directional specular bevel rim (Fresnel reflection: bright top key light, soft ground bounce)
    val borderBrush = Brush.verticalGradient(
        if (isDark) {
            listOf(
                Color.White.copy(alpha = 0.48f),
                Color.White.copy(alpha = 0.20f),
                Color.White.copy(alpha = 0.06f),
                Color.White.copy(alpha = 0.12f)
            )
        } else {
            listOf(
                Color.White.copy(alpha = 0.95f),
                Color.White.copy(alpha = 0.50f),
                Color.White.copy(alpha = 0.18f),
                Color.White.copy(alpha = 0.28f)
            )
        }
    )

    // 4. Ambient occlusion shadow
    val ambientShadowColor = if (isDark) {
        Color.Black.copy(alpha = 0.35f)
    } else {
        Color(0xFF1E293B).copy(alpha = 0.08f)
    }
    val spotShadowColor = if (isDark) {
        Color.Black.copy(alpha = 0.45f)
    } else {
        Color(0xFF0F172A).copy(alpha = 0.12f)
    }

    this
        .shadow(
            elevation = elevation,
            shape = shape,
            clip = false,
            ambientColor = ambientShadowColor,
            spotColor = spotShadowColor
        )
        .clip(shape)
        .background(glassSubstrate)
        .background(surfaceSheen)
        .border(width = borderWidth, brush = borderBrush, shape = shape)
}

