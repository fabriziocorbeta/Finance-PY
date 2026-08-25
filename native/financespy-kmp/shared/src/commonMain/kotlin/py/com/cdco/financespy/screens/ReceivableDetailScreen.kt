package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
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
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun ReceivableDetailScreen(
    viewModel: ReceivableDetailViewModel,
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
        state.receivable?.let { receivable ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(
                            text = receivable.name,
                            style = MaterialTheme.typography.titleLarge,
                            color = FinancePyColors.textPrimary()
                        )

                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            DetailRow(label = "Monto Total", value = "${receivable.currency} ${receivable.totalAmount}")
                            DetailRow(label = "Saldo Original", value = "${receivable.currency} ${receivable.originalBalance}")
                            DetailRow(label = "Saldo Actual", value = "${receivable.currency} ${receivable.balance}")
                            DetailRow(label = "Monto Pagado", value = "${receivable.currency} ${receivable.paidAmount}")
                            DetailRow(label = "Porcentaje Cobrado", value = "${receivable.percentPaid.toInt()}%")

                            val progress = (receivable.percentPaid / 100.0).coerceIn(0.0, 1.0).toFloat()
                            LinearProgressIndicator(
                                progress = { progress },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 4.dp)
                                    .height(8.dp)
                                    .clip(RoundedCornerShape(4.dp)),
                                color = FinancePyColors.success(),
                                trackColor = FinancePyColors.container()
                            )

                            receivable.installmentCount?.let {
                                DetailRow(label = "Cantidad de cuotas", value = it.toString())
                            }
                            receivable.dueDay?.let {
                                DetailRow(label = "Día de pago", value = it.toString())
                            }
                            receivable.notes?.takeIf { it.isNotBlank() }?.let { notes ->
                                DetailRow(label = "Notas", value = notes)
                            }
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

@Composable
private fun DetailRow(label: String, value: String) {
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
