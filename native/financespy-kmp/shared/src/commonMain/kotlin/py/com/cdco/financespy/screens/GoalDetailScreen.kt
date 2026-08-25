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
import androidx.compose.material3.LinearProgressIndicator
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
fun GoalDetailScreen(
    viewModel: GoalDetailViewModel,
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
        state.goal?.let { goal ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(
                            text = goal.name,
                            style = MaterialTheme.typography.titleLarge,
                            color = FinancePyColors.textPrimary()
                        )

                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Monto objetivo: ${goal.targetAmount} ${goal.currency}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            goal.currentBalance?.let { bal ->
                                Text(
                                    text = "Balance actual: $bal ${goal.currency}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            goal.remainingAmount?.let { rem ->
                                Text(
                                    text = "Monto restante: $rem ${goal.currency}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            goal.targetDate?.let { date ->
                                Text(
                                    text = "Fecha objetivo: $date",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            goal.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                                Text(
                                    text = "Notas: $notes",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = "Estado: ",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                Text(
                                    text = goal.state ?: "active",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (goal.state == "active" || goal.state == null) FinancePyColors.success() else FinancePyColors.textSubdued()
                                )
                            }
                        }

                        val percentProgress = ((goal.progressPercent ?: 0).coerceIn(0, 100)) / 100f
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "Progreso",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                Text(
                                    text = "${goal.progressPercent ?: 0}%",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                            }
                            LinearProgressIndicator(
                                progress = { percentProgress },
                                modifier = Modifier.fillMaxWidth(),
                                color = FinancePyColors.buttonBgPrimary(),
                                trackColor = FinancePyColors.borderSecondary()
                            )
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
    }
}
