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
import py.com.cdco.financespy.theme.components.AppTextField

@Composable
fun ReceivableFormScreen(
    viewModel: ReceivableFormViewModel,
    onSaved: () -> Unit
) {
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
            text = if (state.isEditing) "Editar cuenta a cobrar" else "Nueva cuenta a cobrar",
            style = MaterialTheme.typography.titleLarge,
            color = FinancePyColors.textPrimary()
        )

        AppTextField(
            value = state.name,
            onValueChange = viewModel::updateName,
            label = "Nombre de la cuenta"
        )

        AppTextField(
            value = state.totalAmount,
            onValueChange = viewModel::updateTotalAmount,
            label = "Monto total"
        )

        AppTextField(
            value = state.balance,
            onValueChange = viewModel::updateBalance,
            label = if (state.isEditing) "Saldo actual" else "Saldo inicial (opcional, por defecto monto total)"
        )

        AppTextField(
            value = state.installmentCount,
            onValueChange = viewModel::updateInstallmentCount,
            label = "Cantidad de cuotas (opcional)"
        )

        AppTextField(
            value = state.dueDay,
            onValueChange = viewModel::updateDueDay,
            label = "Día de pago (1-31, opcional)"
        )

        AppTextField(
            value = state.currency,
            onValueChange = viewModel::updateCurrency,
            label = "Moneda (ej. PYG, USD)"
        )

        AppTextField(
            value = state.notes,
            onValueChange = viewModel::updateNotes,
            label = "Notas (opcional)"
        )

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
