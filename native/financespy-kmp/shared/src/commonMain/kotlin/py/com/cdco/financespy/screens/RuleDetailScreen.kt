package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun RuleDetailScreen(
    viewModel: RuleDetailViewModel,
    onEditClick: () -> Unit,
    onDeleted: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        state.rule?.let { rule ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = rule.name ?: "(sin nombre)",
                            style = MaterialTheme.typography.titleLarge,
                            color = FinancePyColors.textPrimary()
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Condición: ${rule.conditionType} ${rule.conditionOperator} ${rule.conditionValue}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = "Acción: ${rule.actionType} → ${rule.actionValue}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = "Estado: ",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                Text(
                                    text = if (rule.active) "activa" else "inactiva",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (rule.active) FinancePyColors.success() else FinancePyColors.textSubdued()
                                )
                            }
                        }

                        Column(
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.padding(top = 8.dp)
                        ) {
                            AppButton(
                                text = if (state.isTogglingActive) "..." else if (rule.active) "Desactivar" else "Activar",
                                onClick = { viewModel.toggleActive() },
                                variant = if (rule.active) ButtonVariant.Destructive else ButtonVariant.Primary,
                                modifier = Modifier.fillMaxWidth()
                            )
                            state.toggleError?.let {
                                Text(
                                    text = "Error: $it",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = FinancePyColors.destructive()
                                )
                            }
                            AppButton(
                                text = "Editar",
                                onClick = onEditClick,
                                variant = ButtonVariant.Secondary,
                                modifier = Modifier.fillMaxWidth()
                            )
                            AppButton(
                                text = if (state.isDeleting) "Borrando..." else "Borrar",
                                onClick = { viewModel.delete(onDeleted) },
                                variant = ButtonVariant.Destructive,
                                modifier = Modifier.fillMaxWidth()
                            )
                            state.deleteError?.let {
                                Text(
                                    text = "Error: $it",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = FinancePyColors.destructive()
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            Text(
                text = "Historial de ejecuciones",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary(),
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(state.runs) { run ->
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = run.executedAt,
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textPrimary()
                        )
                        Text(
                            text = run.executionType,
                            style = MaterialTheme.typography.labelMedium,
                            color = FinancePyColors.textSubdued()
                        )
                    }
                    Text(
                        text = run.status,
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
        }
    }
}
