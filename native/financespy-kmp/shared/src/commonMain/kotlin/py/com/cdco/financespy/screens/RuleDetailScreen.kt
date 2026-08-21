package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun RuleDetailScreen(
    viewModel: RuleDetailViewModel,
    onEditClick: () -> Unit,
    onDeleted: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.rule?.let { rule ->
            Text(rule.name ?: "(sin nombre)")
            Text("Condición: ${rule.conditionType} ${rule.conditionOperator} ${rule.conditionValue}")
            Text("Acción: ${rule.actionType} → ${rule.actionValue}")
            Text("Estado: ${if (rule.active) "activa" else "inactiva"}")
            AppButton(
                text = if (state.isTogglingActive) "..." else if (rule.active) "Desactivar" else "Activar",
                onClick = { viewModel.toggleActive() },
                variant = if (rule.active) ButtonVariant.Destructive else ButtonVariant.Primary
            )
            state.toggleError?.let { Text("Error: $it") }
            AppButton(text = "Editar", onClick = onEditClick, variant = ButtonVariant.Secondary)
            AppButton(
                text = if (state.isDeleting) "Borrando..." else "Borrar",
                onClick = { viewModel.delete(onDeleted) },
                variant = ButtonVariant.Destructive
            )
            state.deleteError?.let { Text("Error: $it") }
        }
        Text("Historial de ejecuciones")
        LazyColumn {
            items(state.runs) { run ->
                Text("${run.executedAt} — ${run.status} (${run.executionType})")
            }
        }
    }
}
