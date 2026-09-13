package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.FleetVehicleDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FleetListScreen(
    viewModel: FleetListViewModel,
    onVehicleClick: (String) -> Unit
) {
    val vehicles by viewModel.vehicles.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()

    var showCreateDialog by remember { mutableStateOf(false) }

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showCreateDialog = true },
                containerColor = FinancePyColors.textPrimary(),
                contentColor = FinancePyColors.surface()
            ) {
                Icon(Icons.Default.Add, contentDescription = "Agregar vehículo")
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(FinancePyColors.surface())
                .padding(innerPadding)
        ) {
            if (isLoading && vehicles.isEmpty()) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    color = FinancePyColors.textPrimary()
                )
            } else if (vehicles.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "No hay vehículos registrados",
                        style = MaterialTheme.typography.titleMedium,
                        color = FinancePyColors.textPrimary()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Agregá un vehículo a tu flota para registrar cargas de combustible.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textSecondary()
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(vehicles, key = { it.id }) { vehicle ->
                        FleetVehicleRowItem(
                            vehicle = vehicle,
                            onClick = { onVehicleClick(vehicle.id) }
                        )
                    }
                }
            }
        }

        if (showCreateDialog) {
            CreateFleetVehicleDialog(
                onDismiss = { showCreateDialog = false },
                onConfirm = { plate, brand, model, year, status ->
                    viewModel.createVehicle(plate, brand, model, year, status) {
                        showCreateDialog = false
                    }
                }
            )
        }
    }
}

@Composable
fun FleetVehicleRowItem(
    vehicle: FleetVehicleDto,
    onClick: () -> Unit
) {
    AppCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = vehicle.plate,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                VehicleStatusBadge(status = vehicle.status)
            }

            Spacer(modifier = Modifier.height(4.dp))

            val subtitle = buildString {
                append("${vehicle.brand} ${vehicle.model}")
                if (vehicle.year != null) {
                    append(" (${vehicle.year})")
                }
            }
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = FinancePyColors.textSecondary(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
fun VehicleStatusBadge(status: String) {
    val (label, containerColor, textColor) = when (status) {
        "active" -> Triple("Activo", FinancePyColors.success().copy(alpha = 0.15f), FinancePyColors.success())
        "maintenance" -> Triple("Mantenimiento", FinancePyColors.warning().copy(alpha = 0.15f), FinancePyColors.warning())
        else -> Triple("Inactivo", FinancePyColors.textSecondary().copy(alpha = 0.15f), FinancePyColors.textSecondary())
    }

    Box(
        modifier = Modifier
            .background(containerColor, shape = MaterialTheme.shapes.extraSmall)
            .padding(horizontal = 8.dp, vertical = 4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
            color = textColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateFleetVehicleDialog(
    onDismiss: () -> Unit,
    onConfirm: (plate: String, brand: String, model: String, year: Int?, status: String) -> Unit
) {
    var plate by remember { mutableStateOf("") }
    var brand by remember { mutableStateOf("") }
    var model by remember { mutableStateOf("") }
    var yearText by remember { mutableStateOf("") }
    var status by remember { mutableStateOf("active") }
    var statusExpanded by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Nuevo vehículo",
                style = MaterialTheme.typography.titleLarge,
                color = FinancePyColors.textPrimary()
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                AppTextField(
                    value = plate,
                    onValueChange = { plate = it.uppercase() },
                    label = "Chapa / Matrícula"
                )
                AppTextField(
                    value = brand,
                    onValueChange = { brand = it },
                    label = "Marca"
                )
                AppTextField(
                    value = model,
                    onValueChange = { model = it },
                    label = "Modelo"
                )
                AppTextField(
                    value = yearText,
                    onValueChange = { yearText = it.filter { char -> char.isDigit() } },
                    label = "Año (opcional)"
                )
                ExposedDropdownMenuBox(
                    expanded = statusExpanded,
                    onExpandedChange = { statusExpanded = !statusExpanded }
                ) {
                    AppTextField(
                        value = when (status) {
                            "active" -> "Activo"
                            "maintenance" -> "Mantenimiento"
                            else -> "Inactivo"
                        },
                        onValueChange = {},
                        readOnly = true,
                        label = "Estado",
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = statusExpanded) },
                        modifier = Modifier.menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = statusExpanded,
                        onDismissRequest = { statusExpanded = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Activo") },
                            onClick = { status = "active"; statusExpanded = false }
                        )
                        DropdownMenuItem(
                            text = { Text("Mantenimiento") },
                            onClick = { status = "maintenance"; statusExpanded = false }
                        )
                        DropdownMenuItem(
                            text = { Text("Inactivo") },
                            onClick = { status = "inactive"; statusExpanded = false }
                        )
                    }
                }
            }
        },
        confirmButton = {
            AppButton(
                onClick = {
                    if (plate.isNotBlank() && brand.isNotBlank() && model.isNotBlank()) {
                        onConfirm(plate.trim(), brand.trim(), model.trim(), yearText.toIntOrNull(), status)
                    }
                },
                text = "Guardar"
            )
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancelar", color = FinancePyColors.textSecondary())
            }
        },
        containerColor = FinancePyColors.container(),
        titleContentColor = FinancePyColors.textPrimary(),
        textContentColor = FinancePyColors.textPrimary()
    )
}
