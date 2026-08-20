package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

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
            Button(onClick = { viewModel.toggleActive() }) {
                Text(if (state.isTogglingActive) "..." else if (rule.active) "Desactivar" else "Activar")
            }
            state.toggleError?.let { Text("Error: $it") }
            Button(onClick = onEditClick) { Text("Editar") }
            Button(onClick = { viewModel.delete(onDeleted) }) { Text(if (state.isDeleting) "Borrando..." else "Borrar") }
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
