package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors

@Composable
fun AppTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = modifier,
        shape = RoundedCornerShape(6.dp),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = FinancePyColors.container(),
            unfocusedContainerColor = FinancePyColors.container(),
            disabledContainerColor = FinancePyColors.container(),
            focusedIndicatorColor = FinancePyColors.borderPrimary(),
            unfocusedIndicatorColor = FinancePyColors.borderSecondary(),
            focusedLabelColor = FinancePyColors.textSecondary(),
            unfocusedLabelColor = FinancePyColors.textSubdued(),
            focusedTextColor = FinancePyColors.textPrimary(),
            unfocusedTextColor = FinancePyColors.textPrimary()
        )
    )
}
