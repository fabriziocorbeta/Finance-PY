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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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

@Composable
fun FleetListScreen(
    viewModel: FleetListViewModel,
    onVehicleClick: (String) -> Unit
) {
    val vehicles by viewModel.vehicles.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()
    var showAddDialog by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp)
        ) {
            Text(
                text = "Flota",
                style = MaterialTheme.typography.headlineMedium,
                color = FinancePyColors.textPrimary(),
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(16.dp))

            if (error != null) {
                Text(
                    text = error ?: "",
                    color = FinancePyColors.destructive(),
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
            }

            if (isLoading && vehicles.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = FinancePyColors.textPrimary())
                }
            } else if (vehicles.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No hay vehículos en la flota todavía. Agrega uno nuevo para comenzar a llevar el registro.",
                        style = MaterialTheme.typography.bodyLarge,
                        color = FinancePyColors.textSecondary()
                    )
                }
            } else {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(vehicles, key = { it.id }) { vehicle ->
                        FleetVehicleCard(
                            vehicle = vehicle,
                            onClick = { onVehicleClick(vehicle.id) }
                        )
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = { showAddDialog = true },
            containerColor = FinancePyColors.buttonBgPrimary(),
            contentColor = FinancePyColors.surface(),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(24.dp)
        ) {
            Text(
                text = "+",
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
        }

        if (showAddDialog) {
            AddVehicleDialog(
                onDismiss = { showAddDialog = false },
                onConfirm = { plate, brand, model, year, status, notes ->
                    viewModel.createVehicle(
                        plate = plate,
                        brand = brand,
                        model = model,
                        year = year,
                        status = status,
                        notes = notes,
                        onSuccess = { showAddDialog = false }
                    )
                }
            )
        }
    }
}

@Composable
private fun FleetVehicleCard(
    vehicle: FleetVehicleDto,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(FinancePyColors.container(), RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Column {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = vehicle.plate,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    color = FinancePyColors.textPrimary()
                )

                StatusBadge(status = vehicle.status)
            }

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = "${vehicle.brand} ${vehicle.model}${vehicle.year?.let { " ($it)" } ?: ""}",
                style = MaterialTheme.typography.bodyLarge,
                color = FinancePyColors.textSecondary()
            )

            if (!vehicle.notes.isNull_or_blank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = vehicle.notes!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary(),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

private fun String?.isNull_or_blank(): Boolean = this == null || this.trim().isEmpty()

@Composable
private fun StatusBadge(status: String) {
    val (label, bgColor, textColor) = when (status.lowercase()) {
        "maintenance" -> Triple("En Mantenimiento", FinancePyColors.warning().copy(alpha = 0.2f), FinancePyColors.warning())
        "inactive" -> Triple("Inactivo", FinancePyColors.surface(), FinancePyColors.textSecondary())
        else -> Triple("Activo", FinancePyColors.success().copy(alpha = 0.2f), FinancePyColors.success())
    }

    Box(
        modifier = Modifier
            .background(bgColor, RoundedCornerShape(16.dp))
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = textColor,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun AddVehicleDialog(
    onDismiss: () -> Unit,
    onConfirm: (plate: String, brand: String, model: String, year: Int?, status: String, notes: String?) -> Unit
) {
    var plate by remember { mutableStateOf("") }
    var brand by remember { mutableStateOf("") }
    var model by remember { mutableStateOf("") }
    var yearText by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Nuevo Vehículo", color = FinancePyColors.textPrimary()) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = plate,
                    onValueChange = { plate = it },
                    label = { Text("Chapa / Matrícula") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = brand,
                    onValueChange = { brand = it },
                    label = { Text("Marca") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = model,
                    onValueChange = { model = it },
                    label = { Text("Modelo") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = yearText,
                    onValueChange = { yearText = it },
                    label = { Text("Año (opcional)") },
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notas (opcional)") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    if (plate.isNotBlank() && brand.isNotBlank() && model.isNotBlank()) {
                        onConfirm(
                            plate,
                            brand,
                            model,
                            yearText.toIntOrNull(),
                            "active",
                            notes.ifBlank { null }
                        )
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = FinancePyColors.buttonBgPrimary(), contentColor = FinancePyColors.surface())
            ) {
                Text("Guardar Vehículo")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancelar", color = FinancePyColors.textSecondary())
            }
        },
        containerColor = FinancePyColors.container()
    )
}
