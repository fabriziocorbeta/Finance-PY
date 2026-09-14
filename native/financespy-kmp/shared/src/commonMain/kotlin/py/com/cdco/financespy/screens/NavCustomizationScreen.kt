package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun NavCustomizationScreen(
    viewModel: NavCustomizationViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Volver",
                    tint = FinancePyColors.textPrimary()
                )
            }
            Text(
                text = "Personalizar navegación",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )
        }

        Text(
            text = "Elegí hasta ${uiState.maxSelectable} ítems para la barra inferior (${uiState.selectedIds.size}/${uiState.maxSelectable}). El resto queda disponible en el menú ☰.",
            style = MaterialTheme.typography.bodySmall,
            color = FinancePyColors.textSecondary(),
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = { viewModel.resetToDefault() }) {
                        Text("Restaurar orden por defecto", color = FinancePyColors.textSecondary())
                    }
                }
            }
            items(uiState.selectedIds.mapNotNull { id -> uiState.pool.find { it.id == id } }) { item ->
                val index = uiState.selectedIds.indexOf(item.id)
                NavCustomizationRow(
                    item = item,
                    selected = true,
                    onToggle = { viewModel.toggle(item.id) },
                    trailing = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            IconButton(
                                onClick = { viewModel.moveUp(item.id) },
                                enabled = index > 0
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.KeyboardArrowUp,
                                    contentDescription = "Subir",
                                    tint = if (index > 0) FinancePyColors.textPrimary() else FinancePyColors.textSubdued()
                                )
                            }
                            IconButton(
                                onClick = { viewModel.moveDown(item.id) },
                                enabled = index < uiState.selectedIds.size - 1
                            ) {
                                Icon(
                                    imageVector = Icons.Filled.KeyboardArrowDown,
                                    contentDescription = "Bajar",
                                    tint = if (index < uiState.selectedIds.size - 1) FinancePyColors.textPrimary() else FinancePyColors.textSubdued()
                                )
                            }
                        }
                    }
                )
            }
            val unselected = uiState.pool.filter { it.id !in uiState.selectedIds }
            if (unselected.isNotEmpty()) {
                item {
                    Text(
                        text = "Disponibles (van al menú ☰)",
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary(),
                        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp)
                    )
                }
            }
            items(unselected) { item ->
                NavCustomizationRow(
                    item = item,
                    selected = false,
                    onToggle = { viewModel.toggle(item.id) }
                )
            }
            item { Spacer(modifier = Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun NavCustomizationRow(
    item: NavItem,
    selected: Boolean,
    onToggle: () -> Unit,
    trailing: (@Composable () -> Unit)? = null
) {
    AppCard(modifier = Modifier.fillMaxWidth().clickable(onClick = onToggle)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Checkbox(
                checked = selected,
                onCheckedChange = { onToggle() },
                colors = CheckboxDefaults.colors(checkedColor = FinancePyColors.buttonBgPrimary())
            )
            Icon(
                imageVector = item.icon,
                contentDescription = item.label,
                tint = FinancePyColors.textSecondary(),
                modifier = Modifier.size(20.dp).clip(CircleShape)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = item.label,
                style = MaterialTheme.typography.bodyMedium,
                color = FinancePyColors.textPrimary(),
                modifier = Modifier.weight(1f)
            )
            trailing?.invoke()
        }
    }
}
