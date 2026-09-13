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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.FuelLogDto
import py.com.cdco.financespy.sync.currentIsoDate
import py.com.cdco.financespy.theme.FinancePyColors
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
    ) {
        if (isLoading && vehicle == null) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = FinancePyColors.textPrimary())
            }
        } else if (vehicle != null) {
            val v = vehicle!!
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onBack) {
                        Text("← Volver", color = FinancePyColors.textSecondary())
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            text = v.plate,
                            style = MaterialTheme.typography.headlineMedium,
                            color = FinancePyColors.textPrimary(),
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${v.brand} ${v.model}${v.year?.let { " ($it)" } ?: ""}",
                            style = MaterialTheme.typography.bodyLarge,
                            color = FinancePyColors.textSecondary()
                        )
                    }

                    Button(
                        onClick = { showFuelLogDialog = true },
                        colors = ButtonDefaults.buttonColors(containerColor = FinancePyColors.buttonBgPrimary(), contentColor = FinancePyColors.surface())
                    ) {
                        Text("Cargar combustible")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                if (error != null) {
                    Text(
                        text = error ?: "",
                        color = FinancePyColors.destructive(),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }

                // Metrics Row
                val overallEff = v.average_fuel_efficiency["overall"]
                val totalConsumed = v.monthly_fuel_consumed.values.sum()
                val totalDistance = v.monthly_distance.values.sum()

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    MetricCard(
                        title = "Rendimiento",
                        value = if (overallEff != null && overallEff > 0) "${formatDouble(overallEff)} km/L" else "Sin datos",
                        modifier = Modifier.weight(1f)
                    )
                    MetricCard(
                        title = "Consumo mes",
                        value = if (totalConsumed > 0) "${formatDouble(totalConsumed)} L" else "0 L",
                        modifier = Modifier.weight(1f)
                    )
                    MetricCard(
                        title = "Recorrido mes",
                        value = if (totalDistance > 0) "${formatDouble(totalDistance)} km" else "0 km",
                        modifier = Modifier.weight(1f)
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                Text(
                    text = "Historial de Combustible",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = FinancePyColors.textPrimary()
                )

                Spacer(modifier = Modifier.height(12.dp))

                if (v.fuel_logs.isEmpty()) {
                    Box(
                        modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No hay registros de combustible todavía.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                } else {
                    LazyColumn(
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        items(v.fuel_logs, key = { it.id }) { log ->
                            FuelLogCard(
                                fuelLog = log,
                                onDelete = {
                                    viewModel.deleteFuelLog(log.id) {
                                        viewModel.refresh()
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }

        if (showFuelLogDialog) {
            FuelLogDialog(
                accounts = accounts,
                onDismiss = { showFuelLogDialog = false },
                onConfirm = { accountId, loggedAt, odometer, fuelType, brand, liters, cost, notes ->
                    viewModel.createFuelLog(
                        accountId = accountId,
                        loggedAt = loggedAt,
                        odometer = odometer,
                        fuelType = fuelType,
                        brand = brand,
                        liters = liters,
                        cost = cost,
                        notes = notes,
                        onSuccess = { showFuelLogDialog = false }
                    )
                }
            )
        }
    }
}

@Composable
private fun MetricCard(
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .background(FinancePyColors.container(), RoundedCornerShape(8.dp))
            .padding(12.dp)
    ) {
        Column {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = FinancePyColors.textPrimary(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
private fun FuelLogCard(
    fuelLog: FuelLogDto,
    onDelete: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(FinancePyColors.container(), RoundedCornerShape(8.dp))
            .padding(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = fuelLog.logged_at,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = FinancePyColors.textPrimary()
                    )
                    Text(
                        text = formatMoney(fuelLog.cost, "PYG"),
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold,
                        color = FinancePyColors.textPrimary()
                    )
                }

                Spacer(modifier = Modifier.height(4.dp))

                val linesSummary = fuelLog.fuel_log_lines.joinToString(", ") {
                    val brandStr = if (!it.brand.isNull_or_blank()) " (${it.brand})" else ""
                    "${formatDouble(it.liters)} L ${fuelTypeLabel(it.fuel_type)}$brandStr"
                }

                Text(
                    text = if (linesSummary.isNotBlank()) linesSummary else "${formatDouble(fuelLog.liters)} L",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
                )

                if (fuelLog.odometer != null && fuelLog.odometer > 0) {
                    Text(
                        text = "Km: ${formatDouble(fuelLog.odometer)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }

            TextButton(
                onClick = onDelete,
                colors = ButtonDefaults.textButtonColors(contentColor = FinancePyColors.destructive())
            ) {
                Text("Eliminar", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

private fun fuelTypeLabel(fuelType: String): String = when (fuelType.lowercase()) {
    "nafta" -> "Nafta"
    "alcohol" -> "Alcohol"
    "gnc" -> "GNC"
    "diesel" -> "Diesel"
    else -> fuelType.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
}

private fun formatDouble(value: Double): String {
    val rounded = (value * 10.0).let { if (it >= 0) (it + 0.5).toLong() else (it - 0.5).toLong() } / 10.0
    return rounded.toString()
}

private fun String?.isNull_or_blank(): Boolean = this == null || this.trim().isEmpty()

@Composable
private fun FuelLogDialog(
    accounts: List<AccountDto>,
    onDismiss: () -> Unit,
    onConfirm: (
        accountId: String,
        loggedAt: String,
        odometer: Double?,
        fuelType: String,
        brand: String?,
        liters: Double,
        cost: Double,
        notes: String?
    ) -> Unit
) {
    var selectedAccountId by remember { mutableStateOf(accounts.firstOrNull()?.id ?: "") }
    var accountDropdownExpanded by remember { mutableStateOf(false) }

    var selectedFuelType by remember { mutableStateOf("nafta") }
    var fuelTypeDropdownExpanded by remember { mutableStateOf(false) }

    var brand by remember { mutableStateOf("Podium") }
    var brandDropdownExpanded by remember { mutableStateOf(false) }

    var litersText by remember { mutableStateOf("") }
    var costText by remember { mutableStateOf("") }
    var odometerText by remember { mutableStateOf("") }
    var dateText by remember { mutableStateOf(currentIsoDate()) }
    var notes by remember { mutableStateOf("") }

    val fuelTypes = listOf("nafta", "alcohol", "gnc", "diesel")
    val brandSuggestions = when (selectedFuelType) {
        "nafta" -> listOf("Podium", "Super 97", "Grid", "Prix")
        "diesel" -> listOf("Podium", "Euro 6", "Euro 5")
        else -> emptyList()
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Registro de Combustible", color = FinancePyColors.textPrimary()) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                // Account selector
                Box {
                    val selectedAccount = accounts.find { it.id == selectedAccountId }
                    OutlinedTextField(
                        value = selectedAccount?.name ?: "Seleccione cuenta",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Cuenta") },
                        modifier = Modifier.fillMaxWidth().clickable { accountDropdownExpanded = true }
                    )
                    DropdownMenu(
                        expanded = accountDropdownExpanded,
                        onDismissRequest = { accountDropdownExpanded = false }
                    ) {
                        accounts.forEach { acc ->
                            DropdownMenuItem(
                                text = { Text(acc.name) },
                                onClick = {
                                    selectedAccountId = acc.id
                                    accountDropdownExpanded = false
                                }
                            )
                        }
                    }
                }

                // Fuel type selector
                Box {
                    OutlinedTextField(
                        value = fuelTypeLabel(selectedFuelType),
                        onValueChange = {},
                        readOnly = true,
                        label = { Text("Tipo de Combustible") },
                        modifier = Modifier.fillMaxWidth().clickable { fuelTypeDropdownExpanded = true }
                    )
                    DropdownMenu(
                        expanded = fuelTypeDropdownExpanded,
                        onDismissRequest = { fuelTypeDropdownExpanded = false }
                    ) {
                        fuelTypes.forEach { ft ->
                            DropdownMenuItem(
                                text = { Text(fuelTypeLabel(ft)) },
                                onClick = {
                                    selectedFuelType = ft
                                    brand = when (ft) {
                                        "nafta" -> "Podium"
                                        "diesel" -> "Euro 6"
                                        else -> ""
                                    }
                                    fuelTypeDropdownExpanded = false
                                }
                            )
                        }
                    }
                }

                // Brand selector / input
                Box {
                    OutlinedTextField(
                        value = brand,
                        onValueChange = { brand = it },
                        label = { Text("Marca / Grado") },
                        modifier = Modifier.fillMaxWidth()
                    )
                    if (brandSuggestions.isNotEmpty()) {
                        DropdownMenu(
                            expanded = brandDropdownExpanded,
                            onDismissRequest = { brandDropdownExpanded = false }
                        ) {
                            brandSuggestions.forEach { b ->
                                DropdownMenuItem(
                                    text = { Text(b) },
                                    onClick = {
                                        brand = b
                                        brandDropdownExpanded = false
                                    }
                                )
                            }
                        }
                    }
                }

                OutlinedTextField(
                    value = litersText,
                    onValueChange = { litersText = it },
                    label = { Text("Litros") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = costText,
                    onValueChange = { costText = it },
                    label = { Text("Costo Total") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = odometerText,
                    onValueChange = { odometerText = it },
                    label = { Text("Kilometraje (opcional)") },
                    modifier = Modifier.fillMaxWidth()
                )

                OutlinedTextField(
                    value = dateText,
                    onValueChange = { dateText = it },
                    label = { Text("Fecha (AAAA-MM-DD)") },
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    val liters = litersText.toDoubleOrNull()
                    val cost = costText.toDoubleOrNull()
                    if (selectedAccountId.isNotBlank() && liters != null && liters > 0 && cost != null && cost >= 0) {
                        onConfirm(
                            selectedAccountId,
                            dateText.ifBlank { currentIsoDate() },
                            odometerText.toDoubleOrNull(),
                            selectedFuelType,
                            brand.ifBlank { null },
                            liters,
                            cost,
                            notes.ifBlank { null }
                        )
                    }
                },
                colors = ButtonDefaults.buttonColors(containerColor = FinancePyColors.buttonBgPrimary(), contentColor = FinancePyColors.surface())
            ) {
                Text("Guardar")
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
