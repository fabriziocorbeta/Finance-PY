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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.GoalPledgeDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney

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
                            val targetDouble = goal.targetAmount.toDoubleOrNull() ?: 0.0
                            Text(
                                text = "Monto objetivo: ${formatMoney(targetDouble, goal.currency)}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            goal.currentBalance?.let { bal ->
                                Text(
                                    text = "Balance actual: ${formatMoney(bal, goal.currency)}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            goal.remainingAmount?.let { rem ->
                                Text(
                                    text = "Monto restante: ${formatMoney(rem, goal.currency)}",
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
                                    text = formatGoalState(goal.state),
                                    style = MaterialTheme.typography.labelMedium,
                                    color = if (goal.state == "active" || goal.state == null) FinancePyColors.success() else FinancePyColors.textSubdued()
                                )
                            }
                            goal.status?.let { trackingStatus ->
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = "Ritmo: ",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = FinancePyColors.textSecondary()
                                    )
                                    Text(
                                        text = formatGoalTrackingStatus(trackingStatus),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = when (trackingStatus) {
                                            "on_track", "reached" -> FinancePyColors.success()
                                            "behind" -> FinancePyColors.destructive()
                                            else -> FinancePyColors.textSubdued()
                                        }
                                    )
                                }
                            }
                            goal.pace?.let { paceVal ->
                                Text(
                                    text = "Ritmo actual: ${formatMoney(paceVal, goal.currency)}/mes",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            goal.monthsRemaining?.let { months ->
                                val roundedMonths = kotlin.math.round(months * 10) / 10.0
                                Text(
                                    text = "Meses restantes: $roundedMonths",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            goal.catchUpDelta?.takeIf { it > 0.0 }?.let { delta ->
                                Text(
                                    text = "Para ponerte al día: ${formatMoney(delta, goal.currency)}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.warning()
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

            item {
                val openPledges = state.pledges.filter { it.status == "open" }
                val closedPledges = state.pledges.filter { it.status != "open" }
                val isArchivedOrCompleted = goal.state == "archived" || goal.state == "completed"

                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "Compromisos",
                                style = MaterialTheme.typography.titleMedium,
                                color = FinancePyColors.textPrimary()
                            )
                            if (!isArchivedOrCompleted) {
                                AppButton(
                                    text = "Agregar compromiso",
                                    onClick = { viewModel.openPledgeDialog() },
                                    variant = ButtonVariant.Secondary
                                )
                            }
                        }

                        if (state.pledges.isEmpty()) {
                            Text(
                                text = "No hay compromisos de aporte",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSubdued()
                            )
                        } else {
                            if (openPledges.isNotEmpty()) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(
                                        text = "Abiertos",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = FinancePyColors.textSecondary()
                                    )
                                    openPledges.forEach { pledge ->
                                        PledgeRow(
                                            pledge = pledge,
                                            onRenew = { viewModel.renewPledge(pledge.id) },
                                            onCancel = { viewModel.cancelPledge(pledge.id) }
                                        )
                                    }
                                }
                            }

                            if (closedPledges.isNotEmpty()) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(
                                        text = "Anteriores",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = FinancePyColors.textSecondary()
                                    )
                                    closedPledges.forEach { pledge ->
                                        PledgeRow(
                                            pledge = pledge,
                                            onRenew = null,
                                            onCancel = null
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

    if (state.showPledgeDialog) {
        PledgeDialog(
            accounts = state.pledgeAccounts,
            selectedAccountId = state.pledgeAccountId,
            amount = state.pledgeAmount,
            isSaving = state.isSavingPledge,
            error = state.pledgeError,
            onAccountSelected = viewModel::updatePledgeAccount,
            onAmountChange = viewModel::updatePledgeAmount,
            onConfirm = { viewModel.createPledge() },
            onDismiss = { viewModel.closePledgeDialog() }
        )
    }
}

@Composable
private fun PledgeRow(
    pledge: GoalPledgeDto,
    onRenew: (() -> Unit)?,
    onCancel: (() -> Unit)?
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(FinancePyColors.container())
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = formatMoney(pledge.amount, pledge.currency),
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = pledge.account_name,
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary()
            )
            Text(
                text = formatPledgeStatus(pledge.status, pledge.days_left),
                style = MaterialTheme.typography.labelSmall,
                color = if (pledge.status == "open") FinancePyColors.success() else FinancePyColors.textSubdued()
            )
        }

        if (pledge.status == "open") {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                onRenew?.let {
                    IconButton(onClick = it) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Renovar",
                            tint = FinancePyColors.textPrimary()
                        )
                    }
                }
                onCancel?.let {
                    IconButton(onClick = it) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Cancelar",
                            tint = FinancePyColors.destructive()
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PledgeDialog(
    accounts: List<AccountDto>,
    selectedAccountId: String?,
    amount: String,
    isSaving: Boolean,
    error: String?,
    onAccountSelected: (String) -> Unit,
    onAmountChange: (String) -> Unit,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedAccount = accounts.find { it.id == selectedAccountId }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Agregar compromiso", color = FinancePyColors.textPrimary()) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Column {
                    Text(
                        text = "Cuenta de aporte",
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

fun formatGoalTrackingStatus(status: String?): String {
    return when (status) {
        "on_track" -> "Al día"
        "behind" -> "Atrasado"
        "reached" -> "¡Alcanzada!"
        "no_target_date" -> "Sin fecha límite"
        "archived" -> "Archivada"
        "paused" -> "Pausada"
        "completed" -> "Completada"
        else -> status ?: "Sin estado"
    }
}

private fun formatPledgeStatus(status: String, daysLeft: Int): String {
    return when (status) {
        "open" -> if (daysLeft > 0) "Vence en $daysLeft días" else "Vence hoy"
        "matched" -> "Coincidió"
        "cancelled" -> "Cancelado"
        "expired" -> "Vencido"
        else -> status
    }
}
