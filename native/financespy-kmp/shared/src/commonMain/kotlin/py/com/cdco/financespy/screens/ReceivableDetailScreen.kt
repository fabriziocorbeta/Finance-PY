package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney

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
                            DetailRow(label = "Monto Total", value = formatMoney(receivable.totalAmount, receivable.currency))
                            DetailRow(label = "Saldo Original", value = formatMoney(receivable.originalBalance, receivable.currency))
                            DetailRow(label = "Saldo Actual", value = formatMoney(receivable.balance, receivable.currency))
                            DetailRow(label = "Monto Pagado", value = formatMoney(receivable.paidAmount, receivable.currency))
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
                            if (receivable.balance > 0.0) {
                                AppButton(
                                    text = "Registrar pago",
                                    onClick = { viewModel.openPaymentDialog() },
                                    variant = ButtonVariant.Primary,
                                    modifier = Modifier.fillMaxWidth()
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
    }

    if (state.showPaymentDialog) {
        PaymentDialog(
            accounts = state.paymentAccounts,
            selectedAccountId = state.paymentFromAccountId,
            amount = state.paymentAmount,
            date = state.paymentDate,
            isSaving = state.isRegisteringPayment,
            error = state.paymentError,
            onAccountSelected = viewModel::updatePaymentFromAccountId,
            onAmountChange = viewModel::updatePaymentAmount,
            onDateChange = viewModel::updatePaymentDate,
            onConfirm = { viewModel.registerPayment(onDone = {}) },
            onDismiss = { viewModel.closePaymentDialog() }
        )
    }
}

@Composable
private fun PaymentDialog(
    accounts: List<AccountDto>,
    selectedAccountId: String?,
    amount: String,
    date: String,
    isSaving: Boolean,
    error: String?,
    onAccountSelected: (String) -> Unit,
    onAmountChange: (String) -> Unit,
    onDateChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedAccount = accounts.find { it.id == selectedAccountId }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Registrar pago", color = FinancePyColors.textPrimary()) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Column {
                    Text(
                        text = "Cuenta de origen",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                    Box {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(8.dp))
                                .background(FinancePyColors.container())
                                .padding(horizontal = 12.dp, vertical = 10.dp)
                                .clickable { expanded = true },
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = selectedAccount?.name ?: "Seleccioná una cuenta",
                                color = FinancePyColors.textPrimary()
                            )
                            Icon(
                                imageVector = Icons.Default.ArrowDropDown,
                                contentDescription = null,
                                tint = FinancePyColors.textSecondary()
                            )
                        }
                        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                            accounts.forEach { account ->
                                DropdownMenuItem(
                                    text = { Text(account.name) },
                                    onClick = {
                                        onAccountSelected(account.id)
                                        expanded = false
                                    }
                                )
                            }
                        }
                    }
                }

                AppTextField(
                    value = amount,
                    onValueChange = onAmountChange,
                    label = "Importe"
                )

                AppTextField(
                    value = date,
                    onValueChange = onDateChange,
                    label = "Fecha (AAAA-MM-DD)"
                )

                error?.let {
                    Text(text = it, color = FinancePyColors.destructive(), style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onConfirm, enabled = !isSaving) {
                Text(if (isSaving) "Guardando..." else "Confirmar")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancelar")
            }
        }
    )
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
