package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors

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
    val isDark = isSystemInDarkTheme()

    val backgroundColor = when (variant) {
        ButtonVariant.Primary -> FinancePyColors.buttonBgPrimary()
        ButtonVariant.Secondary -> FinancePyColors.buttonBgSecondary()
        ButtonVariant.SecondaryStrong -> FinancePyColors.buttonBgSecondaryStrong()
        ButtonVariant.Ghost -> FinancePyColors.buttonBgGhost()
        ButtonVariant.Destructive -> FinancePyColors.buttonBgDestructive()
    }

    val contentColor = when (variant) {
        ButtonVariant.Primary -> if (isDark) FinancePyColors.Black else FinancePyColors.White
        ButtonVariant.Destructive -> FinancePyColors.White
        ButtonVariant.Secondary, ButtonVariant.SecondaryStrong, ButtonVariant.Ghost -> FinancePyColors.textPrimary()
    }

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = backgroundColor,
            contentColor = contentColor,
            disabledContainerColor = backgroundColor.copy(alpha = 0.5f),
            disabledContentColor = contentColor.copy(alpha = 0.5f)
        )
    ) {
        Text(text = text)
    }
}
