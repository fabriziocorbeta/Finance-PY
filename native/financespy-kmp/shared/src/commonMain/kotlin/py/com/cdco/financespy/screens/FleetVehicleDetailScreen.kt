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
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.FleetVehicleDto
import py.com.cdco.financespy.api.dto.FuelLogDto
import py.com.cdco.financespy.sync.currentIsoDate
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField
import py.com.cdco.financespy.utils.formatMoney
import py.com.cdco.financespy.utils.formatPercent

@OptIn(ExperimentalMaterial3Api::class)
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = vehicle?.plate ?: "Detalle de vehículo",
                        style = MaterialTheme.typography.titleLarge,
                        color = FinancePyColors.textPrimary(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.Default.ArrowBack,
                            contentDescription = "Volver",
                            tint = FinancePyColors.textPrimary()
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FinancePyColors.container()
                )
            )
        },
        floatingActionButton = {
            if (vehicle != null) {
                FloatingActionButton(
                    onClick = { showFuelLogDialog = true },
                    containerColor = FinancePyColors.textPrimary(),
                    contentColor = FinancePyColors.surface()
                ) {
                    Icon(Icons.Default.Add, contentDescription = "Cargar combustible")
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(FinancePyColors.surface())
                .padding(innerPadding)
        ) {
            val currentVehicle = vehicle
            if (isLoading && currentVehicle == null) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    color = FinancePyColors.textPrimary()
                )
            } else if (currentVehicle != null) {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item {
                        VehicleHeaderCard(vehicle = currentVehicle)
                    }

                    item {
                        MonthlyMetricsCard(vehicle = currentVehicle)
                    }

                    item {
                        Text(
                            text = "Historial de cargas",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary(),
                            modifier = Modifier.padding(top = 8.dp)
                        )
                    }

                    if (currentVehicle.fuel_logs.isEmpty()) {
                        item {
                            Text(
                                text = "Sin cargas de combustible registradas",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                        }
                    } else {
                        items(currentVehicle.fuel_logs, key = { it.id }) { log ->
                            FuelLogRowItem(
                                log = log,
                                onDelete = { viewModel.deleteFuelLog(log.id) }
                            )
                        }
                    }
                }
            }
        }

        if (showFuelLogDialog && vehicle != null) {
            CreateFuelLogDialog(
                accounts = accounts,
                onDismiss = { showFuelLogDialog = false },
                onConfirm = { accountId, loggedAt, odometer, notes, fuelType, brand, liters, cost ->
                    viewModel.createFuelLog(
                        accountId = accountId,
                        loggedAt = loggedAt,
                        odometer = odometer,
                        notes = notes,
                        fuelType = fuelType,
                        brand = brand,
                        liters = liters,
                        cost = cost
                    ) {
                        showFuelLogDialog = false
                    }
                }
            )
        }
    }
}

@Composable
fun VehicleHeaderCard(vehicle: FleetVehicleDto) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${vehicle.brand} ${vehicle.model}",
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                VehicleStatusBadge(status = vehicle.status)
            }

            if (vehicle.year != null) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Año: ${vehicle.year}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textSecondary()
                )
            }

            if (!vehicle.notes.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = vehicle.notes,
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
                )
            }
        }
    }
}

@Composable
fun MonthlyMetricsCard(vehicle: FleetVehicleDto) {
    val overallEfficiency = vehicle.average_fuel_efficiency["overall"]
    val totalConsumed = vehicle.monthly_fuel_consumed.values.sum()
    val totalDistance = vehicle.monthly_distance.values.sum()

    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Métricas del mes",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                MetricItem(
                    label = "Eficiencia general",
                    value = if (overallEfficiency != null) "${formatPercent(overallEfficiency, 1)} km/l" else "N/A"
                )
                MetricItem(
                    label = "Consumo",
                    value = "${formatPercent(totalConsumed, 1)} L"
                )
                MetricItem(
                    label = "Distancia",
                    value = "${formatPercent(totalDistance, 1)} km"
                )
            }
        }
    }
}

@Composable
fun MetricItem(label: String, value: String) {
    Column(horizontalAlignment = Alignment.Start) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = FinancePyColors.textSecondary()
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
            color = FinancePyColors.textPrimary()
        )
    }
}

@Composable
fun FuelLogRowItem(
    log: FuelLogDto,
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
                    text = log.logged_at,
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textSecondary()
                )
                Spacer(modifier = Modifier.height(2.dp))

                val linesSummary = log.fuel_log_lines.joinToString(", ") { line ->
                    val brandStr = if (!line.brand.isNullOrBlank()) " (${line.brand})" else ""
                    "${line.fuel_type.uppercase()}$brandStr - ${formatPercent(line.liters, 1)}L"
                }
                Text(
                    text = if (linesSummary.isNotBlank()) linesSummary else "${formatPercent(log.liters, 1)} L",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                if (log.odometer != null) {
                    Text(
                        text = "Odómetro: ${log.odometer} km",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }

            Spacer(modifier = Modifier.width(8.dp))

            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = formatMoney(log.cost, null),
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                IconButton(onClick = onDelete) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "Eliminar carga",
                        tint = FinancePyColors.textSecondary()
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateFuelLogDialog(
    accounts: List<AccountDto>,
    onDismiss: () -> Unit,
    onConfirm: (
        accountId: String,
        loggedAt: String,
        odometer: Int?,
        notes: String?,
        fuelType: String,
        brand: String?,
        liters: Double,
        cost: Double
    ) -> Unit
) {
    var selectedAccountId by remember { mutableStateOf(accounts.firstOrNull()?.id ?: "") }
    var accountExpanded by remember { mutableStateOf(false) }

    var loggedAt by remember { mutableStateOf(currentIsoDate()) }
    var fuelType by remember { mutableStateOf("nafta") }
    var fuelTypeExpanded by remember { mutableStateOf(false) }

    var brand by remember { mutableStateOf("") }
    var litersText by remember { mutableStateOf("") }
    var costText by remember { mutableStateOf("") }
    var odometerText by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }

    val fuelTypeOptions = listOf("nafta", "diesel", "alcohol", "gnc")

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = "Cargar combustible",
                style = MaterialTheme.typography.titleLarge,
                color = FinancePyColors.textPrimary()
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // Account selector
                ExposedDropdownMenuBox(
                    expanded = accountExpanded,
                    onExpandedChange = { accountExpanded = !accountExpanded }
                ) {
                    val selectedAccountName = accounts.find { it.id == selectedAccountId }?.name ?: "Seleccionar cuenta"
                    AppTextField(
                        value = selectedAccountName,
                        onValueChange = {},
                        readOnly = true,
                        label = "Cuenta de pago",
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = accountExpanded) },
                        modifier = Modifier.menuAnchor()
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
                    AppTextField(
                        value = fuelType.uppercase(),
                        onValueChange = {},
                        readOnly = true,
                        label = "Tipo de combustible",
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = fuelTypeExpanded) },
                        modifier = Modifier.menuAnchor()
                    )
                    ExposedDropdownMenu(
                        expanded = fuelTypeExpanded,
                        onDismissRequest = { fuelTypeExpanded = false }
                    ) {
                        fuelTypeOptions.forEach { typeOption ->
                            DropdownMenuItem(
                                text = { Text(typeOption.uppercase()) },
                                onClick = {
                                    fuelType = typeOption
                                    fuelTypeExpanded = false
                                }
                            )
                        }
                    }
                }

                AppTextField(
                    value = brand,
                    onValueChange = { brand = it },
                    label = "Marca / Emblema (opcional)"
                )

                AppTextField(
                    value = litersText,
                    onValueChange = { litersText = it },
                    label = "Litros"
                )

                AppTextField(
                    value = costText,
                    onValueChange = { costText = it },
                    label = "Costo total"
                )

                AppTextField(
                    value = odometerText,
                    onValueChange = { odometerText = it.filter { char -> char.isDigit() } },
                    label = "Odómetro (km) (opcional)"
                )

                AppTextField(
                    value = loggedAt,
                    onValueChange = { loggedAt = it },
                    label = "Fecha (YYYY-MM-DD)"
                )
            }
        },
        confirmButton = {
            AppButton(
                onClick = {
                    val liters = litersText.toDoubleOrNull()
                    val cost = costText.toDoubleOrNull()
                    if (selectedAccountId.isNotBlank() && liters != null && liters > 0 && cost != null && cost >= 0) {
                        onConfirm(
                            selectedAccountId,
                            loggedAt.ifBlank { currentIsoDate() },
                            odometerText.toIntOrNull(),
                            notes.ifBlank { null },
                            fuelType,
                            brand.ifBlank { null },
                            liters,
                            cost
                        )
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
