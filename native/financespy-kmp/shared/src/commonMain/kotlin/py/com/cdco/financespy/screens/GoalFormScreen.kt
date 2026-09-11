package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField

@Composable
fun GoalFormScreen(
    viewModel: GoalFormViewModel,
    onSaved: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = if (state.isEditing) "Editar meta" else "Nueva meta",
            style = MaterialTheme.typography.titleLarge,
            color = FinancePyColors.textPrimary()
        )

        AppTextField(
            value = state.name,
            onValueChange = viewModel::updateName,
            label = "Nombre de la meta",
            modifier = Modifier.fillMaxWidth()
        )

        AppTextField(
            value = state.targetAmount,
            onValueChange = viewModel::updateTargetAmount,
            label = "Monto objetivo (ej. 10000)",
            modifier = Modifier.fillMaxWidth()
        )

        AppTextField(
            value = state.currency,
            onValueChange = viewModel::updateCurrency,
            label = "Moneda (ej. USD, PYG)",
            modifier = Modifier.fillMaxWidth()
        )

        AppTextField(
            value = state.targetDate,
            onValueChange = viewModel::updateTargetDate,
            label = "Fecha objetivo (AAAA-MM-DD, opcional)",
            modifier = Modifier.fillMaxWidth()
        )

        AppTextField(
            value = state.notes,
            onValueChange = viewModel::updateNotes,
            label = "Notas (opcional)",
            modifier = Modifier.fillMaxWidth()
        )

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "Color",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                GOAL_COLORS.forEach { colorHex ->
                    val colorInt = parseHexColor(colorHex)
                    val isSelected = state.color.equals(colorHex, ignoreCase = true)
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color(colorInt))
                            .then(
                                if (isSelected) Modifier.border(2.dp, FinancePyColors.textPrimary(), CircleShape)
                                else Modifier
                            )
                            .clickable { viewModel.updateColor(colorHex) },
                        contentAlignment = Alignment.Center
                    ) {
                        if (isSelected) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    }
                }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "Ícono",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                GOAL_ICONS.forEach { iconCode ->
                    val isSelected = state.icon.equals(iconCode, ignoreCase = true)
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(if (isSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.container())
                            .clickable { viewModel.updateIcon(if (isSelected) "" else iconCode) }
                            .padding(horizontal = 12.dp, vertical = 8.dp)
                    ) {
                        Text(
                            text = iconCode,
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (isSelected) Color.White else FinancePyColors.textPrimary()
                        )
                    }
                }
            }
        }

        if (state.availableAccounts.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "Cuentas vinculadas (requerido al menos 1)",
                    style = MaterialTheme.typography.titleMedium,
                    color = FinancePyColors.textPrimary()
                )
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        state.availableAccounts.forEach { account ->
                            val isSelected = state.selectedAccountIds.contains(account.id)
                            Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { viewModel.toggleAccountSelection(account.id) },
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = account.name,
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = FinancePyColors.textPrimary()
                                        )
                                        Text(
                                            text = account.currency,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = FinancePyColors.textSecondary()
                                        )
                                    }
                                    Checkbox(
                                        checked = isSelected,
                                        onCheckedChange = { viewModel.toggleAccountSelection(account.id) },
                                        colors = CheckboxDefaults.colors(
                                            checkedColor = FinancePyColors.buttonBgPrimary(),
                                            uncheckedColor = FinancePyColors.borderSecondary()
                                        )
                                    )
                                }
                                if (isSelected) {
                                    val allocatedAmount = state.allocations[account.id].orEmpty()
                                    AppTextField(
                                        value = allocatedAmount,
                                        onValueChange = { viewModel.updateAllocation(account.id, it) },
                                        label = "Monto asignado (vacío = cuenta completa)",
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .padding(start = 16.dp, top = 4.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        AppButton(
            text = if (state.isSaving) "Guardando..." else "Guardar meta",
            onClick = { viewModel.save(onSaved) },
            modifier = Modifier.fillMaxWidth()
        )

        state.error?.let {
            Text(
                text = "Error: $it",
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.destructive()
            )
        }
    }
}

private val GOAL_COLORS = listOf(
    "#e99537", "#4da568", "#6471eb", "#db5a54", "#df4e92",
    "#c44fe9", "#eb5429", "#61c9ea", "#805dee", "#6ad28a"
)

private val GOAL_ICONS = listOf(
    "target", "piggy-bank", "home", "car", "plane", "gift",
    "shopping-cart", "heart", "star", "briefcase", "utensils",
    "wallet", "landmark", "graduation-cap", "shield", "wrench"
)

private fun parseHexColor(hex: String): Long {
    val clean = hex.removePrefix("#")
    val colorLong = clean.toLongOrNull(16) ?: 0x737373L
    return if (clean.length == 6) 0xFF000000L or colorLong else colorLong
}
