package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalFinancePyMetrics
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant

enum class ButtonVariant {
    Primary,
    Secondary,
    SecondaryStrong,
    Ghost,
    Destructive
}

@Composable
fun AppButton(
    text: String,
    onClick: () -> Unit,
    variant: ButtonVariant = ButtonVariant.Primary,
    enabled: Boolean = true,
    modifier: Modifier = Modifier
) {
    val uiVariant = LocalUiVariant.current
    val metrics = LocalFinancePyMetrics.current
    val isDark = isSystemInDarkTheme()

    val backgroundColor = when (uiVariant) {
        UiVariant.MATERIAL3 -> when (variant) {
            ButtonVariant.Primary -> FinancePyColors.buttonBgPrimary()
            ButtonVariant.Secondary -> FinancePyColors.buttonBgSecondary()
            ButtonVariant.SecondaryStrong -> FinancePyColors.buttonBgSecondaryStrong()
            ButtonVariant.Ghost -> FinancePyColors.buttonBgGhost()
            ButtonVariant.Destructive -> FinancePyColors.buttonBgDestructive()
        }
        UiVariant.IOS -> when (variant) {
            ButtonVariant.Primary -> FinancePyColors.buttonBgPrimary()
            ButtonVariant.Secondary -> FinancePyColors.buttonBgPrimary().copy(alpha = if (isDark) 0.20f else 0.14f)
            ButtonVariant.SecondaryStrong -> FinancePyColors.buttonBgSecondary()
            ButtonVariant.Ghost -> Color.Transparent
            ButtonVariant.Destructive -> FinancePyColors.buttonBgDestructive()
        }
    }

    val contentColor = when (uiVariant) {
        UiVariant.MATERIAL3 -> when (variant) {
            ButtonVariant.Primary -> if (isDark) FinancePyColors.Black else FinancePyColors.White
            ButtonVariant.Destructive -> FinancePyColors.White
            ButtonVariant.Secondary, ButtonVariant.SecondaryStrong, ButtonVariant.Ghost -> FinancePyColors.textPrimary()
        }
        UiVariant.IOS -> when (variant) {
            ButtonVariant.Primary -> FinancePyColors.White
            ButtonVariant.Secondary -> FinancePyColors.buttonBgPrimary()
            ButtonVariant.SecondaryStrong -> FinancePyColors.textPrimary()
            ButtonVariant.Ghost -> FinancePyColors.buttonBgPrimary()
            ButtonVariant.Destructive -> FinancePyColors.White
        }
    }

    val contentPadding = when (uiVariant) {
        UiVariant.MATERIAL3 -> ButtonDefaults.ContentPadding
        UiVariant.IOS -> PaddingValues(horizontal = 16.dp, vertical = 10.dp)
    }

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        shape = RoundedCornerShape(metrics.buttonCornerRadius),
        contentPadding = contentPadding,
        elevation = if (uiVariant == UiVariant.IOS) {
            ButtonDefaults.buttonElevation(0.dp, 0.dp, 0.dp, 0.dp, 0.dp)
        } else {
            ButtonDefaults.buttonElevation()
        },
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            contentColor = contentColor,
            disabledContainerColor = backgroundColor.copy(alpha = 0.5f),
            disabledContentColor = contentColor.copy(alpha = 0.5f)
        )
    ) {
        Text(
            text = text,
            style = if (uiVariant == UiVariant.IOS) {
                MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold)
            } else {
                MaterialTheme.typography.labelLarge
            }
        )
    }
}
