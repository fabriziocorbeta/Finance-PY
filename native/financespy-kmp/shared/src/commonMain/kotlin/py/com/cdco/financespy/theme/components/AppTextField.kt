package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalFinancePyMetrics
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant

@Composable
fun AppTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    modifier: Modifier = Modifier
) {
    val variant = LocalUiVariant.current
    val metrics = LocalFinancePyMetrics.current

    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = modifier,
        shape = RoundedCornerShape(metrics.textFieldCornerRadius),
        colors = when (variant) {
            UiVariant.MATERIAL3 -> TextFieldDefaults.colors(
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
            UiVariant.IOS -> TextFieldDefaults.colors(
                focusedContainerColor = FinancePyColors.containerHover(),
                unfocusedContainerColor = FinancePyColors.containerHover(),
                disabledContainerColor = FinancePyColors.containerHover(),
                focusedIndicatorColor = FinancePyColors.buttonBgPrimary(),
                unfocusedIndicatorColor = Color.Transparent,
                focusedLabelColor = FinancePyColors.buttonBgPrimary(),
                unfocusedLabelColor = FinancePyColors.textSecondary(),
                focusedTextColor = FinancePyColors.textPrimary(),
                unfocusedTextColor = FinancePyColors.textPrimary()
            )
        }
    )
}

@Composable
fun AppSearchField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier
) {
    val variant = LocalUiVariant.current
    val metrics = LocalFinancePyMetrics.current

    when (variant) {
        UiVariant.MATERIAL3 -> {
            OutlinedTextField(
                value = value,
                onValueChange = onValueChange,
                placeholder = { Text(placeholder) },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = "Buscar",
                        tint = FinancePyColors.textSecondary()
                    )
                },
                singleLine = true,
                modifier = modifier,
                shape = RoundedCornerShape(metrics.searchFieldCornerRadius)
            )
        }
        UiVariant.IOS -> {
            // Barra de búsqueda estilo UISearchBar / SwiftUI .searchable:
            // fondo gris suave (tertiarySystemGroupedBackground), radio de 10pt,
            // sin borde duro, con ícono de lupa y botón circular de limpiar.
            Row(
                modifier = modifier
                    .clip(RoundedCornerShape(metrics.searchFieldCornerRadius))
                    .background(FinancePyColors.containerHover())
                    .padding(horizontal = 12.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = "Buscar",
                    tint = FinancePyColors.textSecondary(),
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Box(modifier = Modifier.weight(1f)) {
                    if (value.isEmpty()) {
                        Text(
                            text = placeholder,
                            style = MaterialTheme.typography.bodyLarge,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                    BasicTextField(
                        value = value,
                        onValueChange = onValueChange,
                        singleLine = true,
                        textStyle = MaterialTheme.typography.bodyLarge.copy(
                            color = FinancePyColors.textPrimary()
                        ),
                        cursorBrush = SolidColor(FinancePyColors.buttonBgPrimary()),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
                if (value.isNotEmpty()) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Box(
                        modifier = Modifier
                            .size(18.dp)
                            .clip(CircleShape)
                            .background(FinancePyColors.textSubdued())
                            .clickable { onValueChange("") },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Limpiar búsqueda",
                            tint = FinancePyColors.container(),
                            modifier = Modifier.size(12.dp)
                        )
                    }
                }
            }
        }
    }
}
