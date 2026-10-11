package py.com.cdco.financespy.theme.components

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

fun Modifier.liquidGlass(
    shape: Shape = RoundedCornerShape(12.dp)
): Modifier = composed {
    val isDark = isSystemInDarkTheme()

    val glassBg = if (isDark) {
        FinancePyColors.container().copy(alpha = 0.65f)
    } else {
        FinancePyColors.container().copy(alpha = 0.75f)
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
