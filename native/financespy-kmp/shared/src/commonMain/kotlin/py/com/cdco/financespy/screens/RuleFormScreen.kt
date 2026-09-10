package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.RuleRegistryDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun RuleFormScreen(
    viewModel: RuleFormViewModel,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onCancel) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Volver",
                    tint = FinancePyColors.textPrimary()
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = if (state.isEditing) "Editar regla" else "Nueva regla",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }

        if (state.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = FinancePyColors.textPrimary())
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                AppTextField(
                    value = state.name,
                    onValueChange = viewModel::updateName,
                    label = "Nombre (opcional)",
                    modifier = Modifier.fillMaxWidth()
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Activa",
                        style = MaterialTheme.typography.titleMedium,
                        color = FinancePyColors.textPrimary()
                    )
                    Switch(
                        checked = state.active,
                        onCheckedChange = viewModel::updateActive,
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = FinancePyColors.surface(),
                            checkedTrackColor = FinancePyColors.buttonBgPrimary(),
                            uncheckedThumbColor = FinancePyColors.surface(),
                            uncheckedTrackColor = FinancePyColors.borderSecondary()
                        )
                    )
                }

                EffectiveDateSection(state = state, viewModel = viewModel)

                ConditionsSection(state = state, viewModel = viewModel)

                ActionsSection(state = state, viewModel = viewModel)

                AppButton(
                    text = when {
                        state.isSaving -> "Guardando..."
                        state.isEditing -> "Guardar"
                        else -> "Añadir regla"
                    },
                    onClick = { viewModel.save(onSaved) },
                    enabled = !state.isSaving,
                    modifier = Modifier.fillMaxWidth()
                )

                state.error?.let {
                    Text(
                        text = "Error: $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.destructive()
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun EffectiveDateSection(state: RuleFormState, viewModel: RuleFormViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = "Alcance",
            style = MaterialTheme.typography.titleMedium,
            color = FinancePyColors.textPrimary()
        )

        ScopeOption(
            label = "Todas las transacciones pasadas y futuras",
            selected = !state.effectiveDateEnabled,
            onClick = { viewModel.updateEffectiveDateEnabled(false) }
        )
        ScopeOption(
            label = "A partir de una fecha",
            selected = state.effectiveDateEnabled,
            onClick = { viewModel.updateEffectiveDateEnabled(true) }
        )

        if (state.effectiveDateEnabled) {
            AppTextField(
                value = state.effectiveDate,
                onValueChange = viewModel::updateEffectiveDate,
                label = "Fecha (AAAA-MM-DD)",
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun ScopeOption(label: String, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        RadioButton(
            selected = selected,
            onClick = onClick,
            colors = RadioButtonDefaults.colors(
                selectedColor = FinancePyColors.buttonBgPrimary(),
                unselectedColor = FinancePyColors.borderSecondary()
            )
        )
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = FinancePyColors.textPrimary())
    }
}

@Composable
private fun ConditionsSection(state: RuleFormState, viewModel: RuleFormViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Condiciones",
            style = MaterialTheme.typography.titleMedium,
            color = FinancePyColors.textPrimary()
        )

        state.conditionGroups.forEachIndexed { index, entry ->
            when (entry) {
                is ConditionGroupItem.Leaf -> {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        ConditionRow(
                            condition = entry.condition,
                            registry = state.registry,
                            onTypeChange = { viewModel.updateCondition(index, "condition_type", it) },
                            onOperatorChange = { viewModel.updateCondition(index, "operator", it) },
                            onValueChange = { viewModel.updateCondition(index, "value", it) },
                            onRemove = { viewModel.removeCondition(index) }
                        )
                    }
                }

                is ConditionGroupItem.Group -> {
                    GroupCard(
                        group = entry,
                        groupIndex = index,
                        registry = state.registry,
                        viewModel = viewModel
                    )
                }
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            AppButton(
                text = "+ Agregar condición",
                onClick = viewModel::addCondition,
                variant = ButtonVariant.Secondary,
                modifier = Modifier.weight(1f)
            )
            AppButton(
                text = "+ Agregar grupo (Y/O)",
                onClick = viewModel::addConditionGroup,
                variant = ButtonVariant.Secondary,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun GroupCard(
    group: ConditionGroupItem.Group,
    groupIndex: Int,
    registry: RuleRegistryDto?,
    viewModel: RuleFormViewModel
) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    GroupOperatorChip(
                        label = "Y",
                        selected = group.operator == "and",
                        onClick = { viewModel.updateGroupOperator(groupIndex, "and") }
                    )
                    GroupOperatorChip(
                        label = "O",
                        selected = group.operator == "or",
                        onClick = { viewModel.updateGroupOperator(groupIndex, "or") }
                    )
                }
                IconButton(onClick = { viewModel.removeCondition(groupIndex) }) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "Eliminar grupo",
                        tint = FinancePyColors.destructive()
                    )
                }
            }

            group.subConditions.forEachIndexed { subIndex, sub ->
                ConditionRow(
                    condition = sub,
                    registry = registry,
                    onTypeChange = { viewModel.updateSubCondition(groupIndex, subIndex, "condition_type", it) },
                    onOperatorChange = { viewModel.updateSubCondition(groupIndex, subIndex, "operator", it) },
                    onValueChange = { viewModel.updateSubCondition(groupIndex, subIndex, "value", it) },
                    onRemove = { viewModel.removeSubCondition(groupIndex, subIndex) }
                )
            }

            AppButton(
                text = "+ Agregar condición",
                onClick = { viewModel.addSubCondition(groupIndex) },
                variant = ButtonVariant.Secondary,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun GroupOperatorChip(label: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            containerColor = FinancePyColors.container(),
            labelColor = FinancePyColors.textPrimary(),
            selectedContainerColor = FinancePyColors.buttonBgPrimary(),
            selectedLabelColor = FinancePyColors.surface()
        )
    )
}

@Composable
private fun ConditionRow(
    condition: LeafCondition,
    registry: RuleRegistryDto?,
    onTypeChange: (String) -> Unit,
    onOperatorChange: (String) -> Unit,
    onValueChange: (String) -> Unit,
    onRemove: () -> Unit
) {
    val filters = registry?.filters.orEmpty()
    val selectedFilter = filters.find { it.key == condition.conditionType }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            PickerDropdown(
                label = "Condición",
                selectedLabel = selectedFilter?.label ?: "Selecciona una condición",
                options = filters.map { it.label to it.key },
                onSelect = onTypeChange,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = onRemove) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Eliminar condición",
                    tint = FinancePyColors.destructive()
                )
            }
        }

        if (selectedFilter != null) {
            val operatorPairs = selectedFilter.operators.orEmpty()
                .map { (it.getOrNull(0) ?: "") to (it.getOrNull(1) ?: "") }
            val selectedOperatorLabel = operatorPairs.find { it.second == condition.operator }?.first

            PickerDropdown(
                label = "Operador",
                selectedLabel = selectedOperatorLabel ?: "Selecciona un operador",
                options = operatorPairs,
                onSelect = onOperatorChange,
                modifier = Modifier.fillMaxWidth()
            )

            if (condition.operator.isNotBlank() && condition.operator != "is_null") {
                val filterOptions = selectedFilter.options
                if (filterOptions != null) {
                    val optionPairs = filterOptions.map { (it.getOrNull(0) ?: "") to (it.getOrNull(1) ?: "") }
                    val selectedOptionLabel = optionPairs.find { it.second == condition.value }?.first

                    PickerDropdown(
                        label = "Valor",
                        selectedLabel = selectedOptionLabel ?: "Selecciona un valor",
                        options = optionPairs,
                        onSelect = onValueChange,
                        modifier = Modifier.fillMaxWidth()
                    )
                } else {
                    AppTextField(
                        value = condition.value,
                        onValueChange = onValueChange,
                        label = if (selectedFilter.type == "number") "Valor numérico" else "Valor de la condición",
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun ActionsSection(state: RuleFormState, viewModel: RuleFormViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = "Acciones",
            style = MaterialTheme.typography.titleMedium,
            color = FinancePyColors.textPrimary()
        )

        state.actions.forEachIndexed { index, action ->
            AppCard(modifier = Modifier.fillMaxWidth()) {
                ActionRow(
                    action = action,
                    registry = state.registry,
                    onTypeChange = { viewModel.updateAction(index, "action_type", it) },
                    onValueChange = { viewModel.updateAction(index, "value", it) },
                    onRemove = { viewModel.removeAction(index) }
                )
            }
        }

        AppButton(
            text = "+ Agregar acción",
            onClick = viewModel::addAction,
            variant = ButtonVariant.Secondary,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
private fun ActionRow(
    action: LeafAction,
    registry: RuleRegistryDto?,
    onTypeChange: (String) -> Unit,
    onValueChange: (String) -> Unit,
    onRemove: () -> Unit
) {
    val executors = registry?.executors.orEmpty()
    val selectedExecutor = executors.find { it.key == action.actionType }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            PickerDropdown(
                label = "Acción",
                selectedLabel = selectedExecutor?.label ?: "Selecciona una acción",
                options = executors.map { it.label to it.key },
                onSelect = onTypeChange,
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = onRemove) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Eliminar acción",
                    tint = FinancePyColors.destructive()
                )
            }
        }

        if (selectedExecutor != null && selectedExecutor.type != "function") {
            val executorOptions = selectedExecutor.options
            if (executorOptions != null) {
                val optionPairs = executorOptions.map { (it.getOrNull(0) ?: "") to (it.getOrNull(1) ?: "") }
                val selectedOptionLabel = optionPairs.find { it.second == action.value }?.first

                PickerDropdown(
                    label = "Valor",
                    selectedLabel = selectedOptionLabel ?: "Selecciona un valor",
                    options = optionPairs,
                    onSelect = onValueChange,
                    modifier = Modifier.fillMaxWidth()
                )
            } else {
                AppTextField(
                    value = action.value,
                    onValueChange = onValueChange,
                    label = "Valor de la acción",
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

@Composable
private fun PickerDropdown(
    label: String,
    selectedLabel: String,
    options: List<Pair<String, String>>,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }

    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = FinancePyColors.textSecondary()
        )
        Box {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(6.dp))
                    .border(width = 1.dp, color = FinancePyColors.borderSecondary(), shape = RoundedCornerShape(6.dp))
                    .clickable { expanded = true }
                    .padding(horizontal = 12.dp, vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(text = selectedLabel, color = FinancePyColors.textPrimary())
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = FinancePyColors.textSecondary()
                )
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { (optionLabel, optionValue) ->
                    DropdownMenuItem(
                        text = { Text(optionLabel) },
                        onClick = {
                            expanded = false
                            onSelect(optionValue)
                        }
                    )
                }
            }
        }
    }
}
