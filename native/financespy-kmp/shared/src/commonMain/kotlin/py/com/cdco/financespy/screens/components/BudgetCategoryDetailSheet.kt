package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.screens.BudgetCategoryStatus
import py.com.cdco.financespy.screens.BudgetCategoryUiModel
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BudgetCategoryDetailSheet(
    category: BudgetCategoryUiModel,
    currency: String,
    recentTransactions: List<TransactionListItemDto>,
    isLoadingTransactions: Boolean,
    onDismiss: () -> Unit,
    onViewAllTransactions: () -> Unit,
    modifier: Modifier = Modifier
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val categoryColor = parseHexColor(category.color)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = FinancePyColors.container(),
        modifier = modifier
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
                .verticalScroll(rememberScrollState())
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier = Modifier
                            .size(16.dp)
                            .clip(CircleShape)
                            .background(categoryColor)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(
                            text = "Categoría",
                            style = MaterialTheme.typography.labelMedium,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = category.name,
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Cerrar",
                        tint = FinancePyColors.textSecondary()
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Resumen Section Card
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Resumen",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    DetailRow(
                        label = "Gasto del mes",
                        value = "$currency ${category.actualSpending.toInt()}"
                    )

                    val (badgeBg, badgeFg, badgeText) = when (category.status) {
                        BudgetCategoryStatus.OVER_BUDGET -> Triple(FinancePyColors.destructive().copy(alpha = 0.15f), FinancePyColors.destructive(), "Sobre presupuesto")
                        BudgetCategoryStatus.NEAR_LIMIT -> Triple(FinancePyColors.warning().copy(alpha = 0.15f), FinancePyColors.warning(), "Alerta")
                        BudgetCategoryStatus.ON_TRACK -> Triple(FinancePyColors.success().copy(alpha = 0.15f), FinancePyColors.success(), "En camino")
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Estado",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )

                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(badgeBg)
                                    .padding(horizontal = 6.dp, vertical = 2.dp)
                            ) {
                                Text(
                                    text = badgeText,
                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                    color = badgeFg
                                )
                            }
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = category.statusAmountText,
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                                color = if (category.status == BudgetCategoryStatus.OVER_BUDGET) FinancePyColors.destructive() else FinancePyColors.textPrimary()
                            )
                        }
                    }

                    DetailRow(
                        label = "Presupuestado",
                        value = "$currency ${category.budgetedSpending.toInt()}"
                    )

                    DetailRow(
                        label = "Gasto mensual promedio",
                        value = "$currency ${category.avgMonthlyExpense.toInt()}"
                    )

                    DetailRow(
                        label = "Gasto mensual mediano",
                        value = "$currency ${category.medianMonthlyExpense.toInt()}"
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Recent Transactions Card
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Transacciones recientes",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )

                    Spacer(modifier = Modifier.height(12.dp))

                    if (isLoadingTransactions) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(60.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(
                                color = FinancePyColors.textPrimary(),
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    } else if (recentTransactions.isEmpty()) {
                        Text(
                            text = "No hay transacciones recientes en este mes.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary(),
                            modifier = Modifier.padding(vertical = 8.dp)
                        )
                    } else {
                        recentTransactions.forEach { tx ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 6.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = tx.name,
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                                        color = FinancePyColors.textPrimary()
                                    )
                                    Text(
                                        text = tx.date,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = FinancePyColors.textSecondary()
                                    )
                                }

                                Text(
                                    text = "$currency ${(tx.amount_cents / 100.0).toInt()}",
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.textPrimary()
                                )
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    AppButton(
                        text = "Ver todas las transacciones de la categoría",
                        onClick = onViewAllTransactions,
                        variant = ButtonVariant.Secondary,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
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
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
            color = FinancePyColors.textPrimary()
        )
    }
}
