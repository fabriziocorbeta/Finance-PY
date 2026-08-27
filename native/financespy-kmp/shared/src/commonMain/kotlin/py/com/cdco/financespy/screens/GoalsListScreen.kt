package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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

@Composable
fun GoalsListScreen(
    viewModel: GoalsListViewModel,
    onGoalClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val goals by viewModel.goals.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                AppButton(
                    text = "Nueva meta",
                    onClick = onCreateClick,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            if (goals.isEmpty()) {
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "No tenés metas aún. ¡Creá una nueva meta para empezar a planificar!",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
            } else {
                items(goals) { goal ->
                    AppCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onGoalClick(goal.id) }
                    ) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = goal.name,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                                Text(
                                    text = goal.state ?: "active",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (goal.state == "active" || goal.state == null) FinancePyColors.success() else FinancePyColors.textSubdued()
                                )
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Objetivo: ${goal.targetAmount} ${goal.currency}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                val percent = goal.progressPercent ?: 0
                                Text(
                                    text = "$percent%",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                            }

                            val percentProgress = ((goal.progressPercent ?: 0).coerceIn(0, 100)) / 100f
                            LinearProgressIndicator(
                                progress = { percentProgress },
                                modifier = Modifier.fillMaxWidth(),
                                color = FinancePyColors.buttonBgPrimary(),
                                trackColor = FinancePyColors.borderSecondary()
                            )
                        }
                    }
                }
            }
        }
    }
}
