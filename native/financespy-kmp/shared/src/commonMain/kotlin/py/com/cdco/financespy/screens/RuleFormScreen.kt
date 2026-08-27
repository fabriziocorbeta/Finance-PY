package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField

@Composable
fun RuleFormScreen(viewModel: RuleFormViewModel, onSaved: () -> Unit) {
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
            text = if (state.isEditing) "Editar regla" else "Nueva regla",
            style = MaterialTheme.typography.titleLarge,
            color = FinancePyColors.textPrimary()
        )

        AppTextField(
            value = state.name,
            onValueChange = viewModel::updateName,
            label = "Nombre (opcional)"
        )

        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = "Condición: ${state.conditionType}",
                style = MaterialTheme.typography.labelMedium,
                color = FinancePyColors.textSecondary()
            )
            AppTextField(
                value = state.conditionValue,
                onValueChange = viewModel::updateConditionValue,
                label = "Valor de la condición (texto, id de comercio o id de categoría según el tipo)"
            )
        }

        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = "Acción: ${state.actionType}",
                style = MaterialTheme.typography.labelMedium,
                color = FinancePyColors.textSecondary()
            )
            AppTextField(
                value = state.actionValue,
                onValueChange = viewModel::updateActionValue,
                label = "Valor de la acción (id de categoría o de tag)"
            )
        }

        if (state.categories.isNotEmpty() || state.tags.isNotEmpty() || state.merchants.isNotEmpty()) {
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (state.categories.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Categorías disponibles",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = state.categories.joinToString { "${it.name} (${it.id})" },
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textPrimary()
                            )
                        }
                    }
                    if (state.tags.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Tags disponibles",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = state.tags.joinToString { "${it.name} (${it.id})" },
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textPrimary()
                            )
                        }
                    }
                    if (state.merchants.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Comercios disponibles",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = state.merchants.joinToString { "${it.name} (${it.id})" },
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textPrimary()
                            )
                        }
                    }
                }
            }
        }

        AppButton(
            text = if (state.isSaving) "Guardando..." else "Guardar",
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
