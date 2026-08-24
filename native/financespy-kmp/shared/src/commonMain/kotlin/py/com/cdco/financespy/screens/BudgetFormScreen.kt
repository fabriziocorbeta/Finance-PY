package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
fun BudgetFormScreen(viewModel: BudgetFormViewModel, onSaved: () -> Unit) {
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
            text = if (state.isEditing) "Editar presupuesto" else "Nuevo presupuesto",
            style = MaterialTheme.typography.titleLarge,
            color = FinancePyColors.textPrimary()
        )

        if (!state.isEditing) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                AppTextField(
                    value = state.year,
                    onValueChange = viewModel::updateYear,
                    label = "Año (YYYY)",
                    modifier = Modifier.weight(1f)
                )
                AppTextField(
                    value = state.month,
                    onValueChange = viewModel::updateMonth,
                    label = "Mes (MM)",
                    modifier = Modifier.weight(1f)
                )
            }
        }

        AppTextField(
            value = state.budgetedSpending,
            onValueChange = viewModel::updateBudgetedSpending,
            label = "Presupuesto de gastos"
        )

        AppTextField(
            value = state.expectedIncome,
            onValueChange = viewModel::updateExpectedIncome,
            label = "Ingreso esperado (opcional)"
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
