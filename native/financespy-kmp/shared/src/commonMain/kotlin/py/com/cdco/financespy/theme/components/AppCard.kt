package py.com.cdco.financespy.theme.components

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors

// Enter/exit pair for a glass surface appearing or disappearing, modeled on
// SwiftUI's GlassEffectTransition.materialize (see Apple's
// developer.apple.com/documentation/swiftui/glasseffecttransition) -- scale
// up from slightly condensed + fade in, not a plain fade, so the surface
// reads as "forming" rather than just appearing. Compose has no native glass
// transition type to port; this reproduces the feel with scaleIn/fadeIn.
object GlassTransitions {
    val materializeEnter: EnterTransition = scaleIn(
        initialScale = 0.9f,
        animationSpec = tween(220)
    ) + fadeIn(animationSpec = tween(180))

    val materializeExit: ExitTransition = scaleOut(
        targetScale = 0.9f,
        animationSpec = tween(160)
    ) + fadeOut(animationSpec = tween(140))
}

fun Modifier.liquidGlass(
    shape: Shape = RoundedCornerShape(12.dp),
    // Bumps the background's opacity (0f = unchanged). AppCard and dialogs sit
    // on their own against a single background and read fine at the default
    // alpha. AppBottomNav instead floats as a permanent overlay on top of
    // scrolling content -- on screens with several stacked AppCards (Dashboard,
    // Reportes) a card's own near-white background can end up sitting directly
    // behind the nav at rest, and at the default alpha the two blend into each
    // other: the card's numbers/chart visibly bleed into the nav row instead of
    // being dimmed by it. The nav passes a boost so it stays legible regardless
    // of what's scrolled behind it, without changing how cards/dialogs look.
    contrastBoost: Float = 0f
): Modifier = composed {
    val isDark = isSystemInDarkTheme()

    val glassBg = if (isDark) {
        FinancePyColors.container().copy(alpha = (0.65f + contrastBoost).coerceAtMost(1f))
    } else {
        FinancePyColors.container().copy(alpha = (0.75f + contrastBoost).coerceAtMost(1f))
    }

    val borderGradient = Brush.linearGradient(
        colors = if (isDark) {
            listOf(
                Color.White.copy(alpha = 0.25f),
                Color.White.copy(alpha = 0.05f)
            )
        } else {
            listOf(
                Color.White.copy(alpha = 0.9f),
                Color.White.copy(alpha = 0.3f)
            )
        }
    )

    this
        .shadow(
            elevation = 8.dp,
            shape = shape,
            clip = false,
            ambientColor = Color.Black.copy(alpha = 0.05f),
            spotColor = Color.Black.copy(alpha = 0.1f)
        )
        .clip(shape)
        .background(glassBg)
        .border(width = 1.5.dp, brush = borderGradient, shape = shape)
}

@Composable
fun AppCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier = modifier
            .liquidGlass(shape)
            .padding(16.dp),
        content = content
    )
}
