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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun BudgetDetailScreen(
    viewModel: BudgetDetailViewModel,
    onEditClick: () -> Unit,
    onDeleted: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    var showDeleteConfirmDialog by remember { mutableStateOf(false) }

    if (showDeleteConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirmDialog = false },
            title = { Text("Eliminar presupuesto") },
            text = { Text("¿Estás seguro de que querés eliminar este presupuesto?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirmDialog = false
                        viewModel.delete(onDeleted)
                    }
                ) {
                    Text("Eliminar", color = FinancePyColors.destructive())
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirmDialog = false }) {
                    Text("Cancelar")
                }
            }
        )
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        state.budget?.let { budget ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(
                            text = formatBudgetPeriod(budget.startDate),
                            style = MaterialTheme.typography.titleLarge,
                            color = FinancePyColors.textPrimary()
                        )

                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            BudgetDetailRow("Período", "${budget.startDate} al ${budget.endDate}")
                            BudgetDetailRow("Moneda", budget.currency)
                            BudgetDetailRow("Presupuesto de gasto", "${budget.budgetedSpending} ${budget.currency}")
                            BudgetDetailRow("Gasto actual", "${budget.actualSpending} ${budget.currency}")
                            BudgetDetailRow("Porcentaje gastado", "${budget.percentOfBudgetSpent}%")
                            BudgetDetailRow("Gasto asignado", "${budget.allocatedSpending} ${budget.currency}")
                            BudgetDetailRow("Disponible para gastar", "${budget.availableToSpend} ${budget.currency}")
                            BudgetDetailRow("Ingreso esperado", "${budget.expectedIncome} ${budget.currency}")
                            BudgetDetailRow("Ingreso actual", "${budget.actualIncome} ${budget.currency}")
                            BudgetDetailRow("Ingreso pendiente", "${budget.remainingExpectedIncome} ${budget.currency}")
                        }

                        Column(
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.padding(top = 8.dp)
                        ) {
                            AppButton(
                                text = "Editar",
                                onClick = onEditClick,
                                variant = ButtonVariant.Secondary,
                                modifier = Modifier.fillMaxWidth()
                            )
                            AppButton(
                                text = if (state.isDeleting) "Borrando..." else "Borrar",
                                onClick = { showDeleteConfirmDialog = true },
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
    }
}

@Composable
private fun BudgetDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textSecondary()
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textPrimary()
        )
    }
}
