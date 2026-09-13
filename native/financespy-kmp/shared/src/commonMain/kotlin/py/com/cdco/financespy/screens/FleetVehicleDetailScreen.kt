package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.FleetVehicleDto
import py.com.cdco.financespy.api.dto.FuelLogDto
import py.com.cdco.financespy.sync.currentIsoDate
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun FleetVehicleDetailScreen(
    viewModel: FleetVehicleDetailViewModel,
    onBack: () -> Unit
) {
    val vehicle by viewModel.vehicle.collectAsState()
    val accounts by viewModel.accounts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()
    var showFuelLogDialog by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
            .padding(16.dp)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Volver",
                        tint = FinancePyColors.textPrimary()
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = vehicle?.let { "${it.brand} ${it.model} (${it.plate})" } ?: "Detalle del Vehículo",
                    style = MaterialTheme.typography.titleLarge,
                    color = FinancePyColors.textPrimary(),
                    fontWeight = FontWeight.Bold
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            if (isLoading && vehicle == null) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = FinancePyColors.buttonBgPrimary())
                }
            } else if (error != null && vehicle == null) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(text = error ?: "Error", color = FinancePyColors.destructive())
                }
            } else vehicle?.let { currentVehicle ->
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item {
                        MetricsSummaryCard(vehicle = currentVehicle)
                    }

                    item {
                        Text(
                            text = "Historial de Cargas",
                            style = MaterialTheme.typography.titleMedium,
                            color = FinancePyColors.textPrimary(),
                            fontWeight = FontWeight.Bold
                        )
                    }

                    if (currentVehicle.fuel_logs.isEmpty()) {
                        item {
                            Text(
                                text = "No hay cargas de combustible registradas",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                        }
                    } else {
                        items(currentVehicle.fuel_logs, key = { it.id }) { log ->
                            FuelLogItemCard(
                                fuelLog = log,
                                onDelete = { viewModel.deleteFuelLog(log.id) }
                            )
                        }
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = { showFuelLogDialog = true },
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(16.dp),
            containerColor = FinancePyColors.buttonBgPrimary(),
            contentColor = FinancePyColors.surface()
        ) {
            Icon(Icons.Default.Add, contentDescription = "Cargar combustible")
        }

        if (showFuelLogDialog) {
            CreateFuelLogDialog(
                accounts = accounts,
                onDismiss = { showFuelLogDialog = false },
                onCreate = { accountId, date, odo, fuelType, brand, liters, cost, notes ->
                    viewModel.createFuelLog(accountId, date, odo, fuelType, brand, liters, cost, notes) {
                        showFuelLogDialog = false
                    }
                }
            )
        }
    }
}

private fun formatDouble(value: Double): String {
    val rounded = (value * 10).toLong() / 10.0
    return rounded.toString()
}

@Composable
fun MetricsSummaryCard(vehicle: FleetVehicleDto) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Métricas del Mes",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary(),
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(12.dp))

            val overallEfficiency = vehicle.average_fuel_efficiency["overall"]
            val totalConsumed = vehicle.monthly_fuel_consumed.values.sum()
            val totalDistance = vehicle.monthly_distance.values.sum()

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                MetricItem(
                    title = "Eficiencia",
                    value = overallEfficiency?.let { "${formatDouble(it)} km/l" } ?: "N/A"
                )
                MetricItem(
                    title = "Consumo Mes",
                    value = "${formatDouble(totalConsumed)} L"
                )
                MetricItem(
                    title = "Distancia Mes",
                    value = "${formatDouble(totalDistance)} km"
                )
            }
        }
    }
}

@Composable
fun MetricItem(title: String, value: String) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = FinancePyColors.textSecondary()
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            color = FinancePyColors.textPrimary(),
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
fun FuelLogItemCard(
    fuelLog: FuelLogDto,
    onDelete: () -> Unit
) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = fuelLog.logged_at.take(10),
                    style = MaterialTheme.typography.titleSmall,
                    color = FinancePyColors.textPrimary(),
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "${fuelLog.liters} L • ${formatMoney(fuelLog.cost, "USD")}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textSecondary()
                )
                fuelLog.odometer?.let { odo ->
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = "Odómetro: ${odo.toLong()} km",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }

            IconButton(onClick = onDelete) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Eliminar carga",
                    tint = FinancePyColors.destructive()
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateFuelLogDialog(
    accounts: List<AccountDto>,
    onDismiss: () -> Unit,
    onCreate: (accountId: String, date: String, odo: Double?, fuelType: String, brand: String?, liters: Double, cost: Double, notes: String?) -> Unit
) {
    var selectedAccountId by remember { mutableStateOf(accounts.firstOrNull()?.id ?: "") }
    var accountExpanded by remember { mutableStateOf(false) }

    var fuelType by remember { mutableStateOf("nafta") }
    var fuelTypeExpanded by remember { mutableStateOf(false) }
    val fuelTypes = listOf("nafta", "alcohol", "gnc", "diesel")

    var brand by remember { mutableStateOf("") }
    var litersText by remember { mutableStateOf("") }
    var costText by remember { mutableStateOf("") }
    var odometerText by remember { mutableStateOf("") }
    var dateText by remember { mutableStateOf(currentIsoDate()) }
    var notes by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Cargar Combustible",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                // Account selector
                ExposedDropdownMenuBox(
                    expanded = accountExpanded,
                    onExpandedChange = { accountExpanded = !accountExpanded }
                ) {
                    val selectedAccount = accounts.find { it.id == selectedAccountId }
                    OutlinedTextField(
                        value = selectedAccount?.name ?: "Seleccionar cuenta",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Cuenta") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = accountExpanded) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = accountExpanded,
                        onDismissRequest = { accountExpanded = false }
                    ) {
                        accounts.forEach { acc ->
                            DropdownMenuItem(
                                text = { Text(acc.name) },
                                onClick = {
                                    selectedAccountId = acc.id
                                    accountExpanded = false
                                }
                            )
                        }
                    }
                }

                // Fuel type selector
                ExposedDropdownMenuBox(
                    expanded = fuelTypeExpanded,
                    onExpandedChange = { fuelTypeExpanded = !fuelTypeExpanded }
                ) {
                    OutlinedTextField(
                        value = fuelType.uppercase(),
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Tipo de Combustible") },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = fuelTypeExpanded) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = fuelTypeExpanded,
                        onDismissRequest = { fuelTypeExpanded = false }
                    ) {
                        fuelTypes.forEach { type ->
                            DropdownMenuItem(
                                text = { Text(type.uppercase()) },
                                onClick = {
                                    fuelType = type
                                    fuelTypeExpanded = false
                                }
                            )
                        }
                    }
                }

                OutlinedTextField(
                    value = litersText,
                    onValueChange = { litersText = it },
                    label = { Text("Litros") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = costText,
                    onValueChange = { costText = it },
                    label = { Text("Costo") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = odometerText,
                    onValueChange = { odometerText = it },
                    label = { Text("Odómetro (opcional)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = brand,
                    onValueChange = { brand = it },
                    label = { Text("Marca / Estación (opcional)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = dateText,
                    onValueChange = { dateText = it },
                    label = { Text("Fecha (YYYY-MM-DD)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val liters = litersText.toDoubleOrNull()
                    val cost = costText.toDoubleOrNull()
                    val odo = odometerText.toDoubleOrNull()
                    if (selectedAccountId.isNotBlank() && liters != null && liters > 0 && cost != null && cost >= 0) {
                        onCreate(
                            selectedAccountId,
                            dateText.ifBlank { currentIsoDate() },
                            odo,
                            fuelType,
                            brand.trim().ifBlank { null },
                            liters,
                            cost,
                            notes.trim().ifBlank { null }
                        )
                    }
                }
            ) {
                Text("Guardar", color = FinancePyColors.textPrimary())
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancelar", color = FinancePyColors.textSecondary())
            }
        }
    )
}
