package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.remember
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun RuleFormScreen(viewModel: RuleFormViewModel, onSaved: () -> Unit) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text(if (state.isEditing) "Editar regla" else "Nueva regla")

        TextField(value = state.name, onValueChange = viewModel::updateName, label = { Text("Nombre (opcional)") })

        Text("Condición: ${state.conditionType}")
        TextField(
            value = state.conditionValue,
            onValueChange = viewModel::updateConditionValue,
            label = { Text("Valor de la condición (texto, id de comercio o id de categoría según el tipo)") }
        )

        Text("Acción: ${state.actionType}")
        TextField(
            value = state.actionValue,
            onValueChange = viewModel::updateActionValue,
            label = { Text("Valor de la acción (id de categoría o de tag)") }
        )

        if (state.categories.isNotEmpty()) {
            Text("Categorías disponibles: ${state.categories.joinToString { "${it.name} (${it.id})" }}")
        }
        if (state.tags.isNotEmpty()) {
            Text("Tags disponibles: ${state.tags.joinToString { "${it.name} (${it.id})" }}")
        }
        if (state.merchants.isNotEmpty()) {
            Text("Comercios disponibles: ${state.merchants.joinToString { "${it.name} (${it.id})" }}")
        }

        Button(onClick = { viewModel.save(onSaved) }) { Text(if (state.isSaving) "Guardando..." else "Guardar") }
        state.error?.let { Text("Error: $it") }
    }
}
