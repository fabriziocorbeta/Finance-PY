package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun ReceivablesListScreen(
    viewModel: ReceivablesListViewModel,
    onReceivableClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val receivables by viewModel.receivables.collectAsState()

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
                    text = "Nueva cuenta a cobrar",
                    onClick = onCreateClick,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            if (receivables.isEmpty()) {
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "No hay cuentas a cobrar registradas.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
            } else {
                items(receivables) { receivable ->
                    AppCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onReceivableClick(receivable.id) }
                    ) {
                        Column(
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = receivable.name,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                                Text(
                                    text = "${receivable.currency} ${receivable.totalAmount}",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Saldo: ${receivable.currency} ${receivable.balance}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                Text(
                                    text = "Cobrado: ${receivable.percentPaid.toInt()}%",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = FinancePyColors.success()
                                )
                            }

                            val progress = (receivable.percentPaid / 100.0).coerceIn(0.0, 1.0).toFloat()
                            LinearProgressIndicator(
                                progress = { progress },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(6.dp)
                                    .clip(RoundedCornerShape(3.dp)),
                                color = FinancePyColors.success(),
                                trackColor = FinancePyColors.container()
                            )

                            if (receivable.installmentCount != null || receivable.dueDay != null) {
                                val cuotasText = receivable.installmentCount?.let { "$it cuotas" } ?: ""
                                val dueDayText = receivable.dueDay?.let { "Día $it" } ?: ""
                                val extraInfo = listOf(cuotasText, dueDayText).filter { it.isNotEmpty() }.joinToString(" • ")
                                if (extraInfo.isNotEmpty()) {
                                    Text(
                                        text = extraInfo,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = FinancePyColors.textSubdued()
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
