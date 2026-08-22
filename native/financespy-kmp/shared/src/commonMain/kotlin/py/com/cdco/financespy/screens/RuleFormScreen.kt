package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppTextField

@Composable
fun RuleFormScreen(viewModel: RuleFormViewModel, onSaved: () -> Unit) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text(if (state.isEditing) "Editar regla" else "Nueva regla")

        AppTextField(value = state.name, onValueChange = viewModel::updateName, label = "Nombre (opcional)")

        Text("Condición: ${state.conditionType}")
        AppTextField(
            value = state.conditionValue,
            onValueChange = viewModel::updateConditionValue,
            label = "Valor de la condición (texto, id de comercio o id de categoría según el tipo)"
        )

        Text("Acción: ${state.actionType}")
        AppTextField(
            value = state.actionValue,
            onValueChange = viewModel::updateActionValue,
            label = "Valor de la acción (id de categoría o de tag)"
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

        AppButton(
            text = if (state.isSaving) "Guardando..." else "Guardar",
            onClick = { viewModel.save(onSaved) }
        )
        state.error?.let { Text("Error: $it") }
    }
}
