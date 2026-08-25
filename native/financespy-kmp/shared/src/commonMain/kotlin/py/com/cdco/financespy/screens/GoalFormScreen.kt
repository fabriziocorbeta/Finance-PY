package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { viewModel.toggleAccountSelection(account.id) }
                                    .padding(vertical = 4.dp),
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
