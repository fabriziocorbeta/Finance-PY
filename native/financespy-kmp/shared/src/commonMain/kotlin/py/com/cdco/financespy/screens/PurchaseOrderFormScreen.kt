package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PurchaseOrderFormScreen(
    viewModel: PurchaseOrderFormViewModel,
    onSaved: () -> Unit,
    onCancel: () -> Unit
) {
    val existingPo by viewModel.purchaseOrder.collectAsState()
    val availableProducts by viewModel.availableProducts.collectAsState()
    val availableAccounts by viewModel.availableAccounts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isSaving by viewModel.isSaving.collectAsState()
    val error by viewModel.error.collectAsState()

    var supplierName by remember { mutableStateOf("") }
    var currency by remember { mutableStateOf("pyg") }
    var notes by remember { mutableStateOf("") }
    var accountId by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf<PurchaseOrderFormItemState>() }

    LaunchedEffect(existingPo) {
        existingPo?.let { po ->
            supplierName = po.supplier_name ?: ""
            currency = po.currency
            notes = po.notes ?: ""
            accountId = po.account_id ?: accountId
            items.clear()
            po.purchase_order_items.forEach { item ->
                items.add(
                    PurchaseOrderFormItemState(
                        productId = item.product_id,
                        quantity = item.quantity,
                        unitCost = item.unit_cost
                    )
                )
            }
        }
    }

    LaunchedEffect(availableAccounts) {
        if (accountId.isBlank()) {
            availableAccounts.firstOrNull()?.let { accountId = it.id }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (existingPo != null) "Editar Orden de Compra" else "Nueva Orden de Compra",
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onCancel) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Volver")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FinancePyColors.container(),
                    titleContentColor = FinancePyColors.textPrimary()
                )
            )
        },
        containerColor = FinancePyColors.surface()
    ) { padding ->
        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                if (error != null) {
                    Text(
                        text = error ?: "",
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }

                OutlinedTextField(
                    value = supplierName,
                    onValueChange = { supplierName = it },
                    label = { Text("Proveedor") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notas") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2
                )

                run {
                    var accountExpanded by remember { mutableStateOf(false) }
                    val selectedAccount = availableAccounts.find { it.id == accountId }

                    ExposedDropdownMenuBox(
                        expanded = accountExpanded,
                        onExpandedChange = { accountExpanded = !accountExpanded }
                    ) {
                        OutlinedTextField(
                            value = selectedAccount?.name ?: "Seleccionar Cuenta",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("Cuenta") },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = accountExpanded) },
                            modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                        )
                        ExposedDropdownMenu(
                            expanded = accountExpanded,
                            onDismissRequest = { accountExpanded = false }
                        ) {
                            availableAccounts.forEach { acc ->
                                DropdownMenuItem(
                                    text = { Text(acc.name) },
                                    onClick = {
                                        accountId = acc.id
                                        accountExpanded = false
                                    }
                                )
                            }
                        }
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Ítems de Orden",
                        style = MaterialTheme.typography.titleMedium,
                        color = FinancePyColors.textPrimary()
                    )

                    IconButton(
                        onClick = {
                            val firstProduct = availableProducts.firstOrNull()
                            items.add(
                                PurchaseOrderFormItemState(
                                    productId = firstProduct?.id ?: "",
                                    quantity = 1,
                                    unitCost = firstProduct?.buy_price ?: 0.0
                                )
                            )
                        }
                    ) {
                        Icon(Icons.Default.Add, contentDescription = "Agregar ítem")
                    }
                }

                items.forEachIndexed { index, itemState ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("Ítem ${index + 1}", style = MaterialTheme.typography.bodySmall, color = FinancePyColors.textSecondary())
                                IconButton(onClick = { items.removeAt(index) }) {
                                    Icon(Icons.Default.Delete, contentDescription = "Quitar ítem", tint = MaterialTheme.colorScheme.error)
                                }
                            }

                            var expanded by remember { mutableStateOf(false) }
                            val selectedProd = availableProducts.find { it.id == itemState.productId }

                            ExposedDropdownMenuBox(
                                expanded = expanded,
                                onExpandedChange = { expanded = !expanded }
                            ) {
                                OutlinedTextField(
                                    value = selectedProd?.name ?: "Seleccionar Producto",
                                    onValueChange = {},
                                    readOnly = true,
                                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                                    modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                                )
                                ExposedDropdownMenu(
                                    expanded = expanded,
                                    onDismissRequest = { expanded = false }
                                ) {
                                    availableProducts.forEach { p ->
                                        DropdownMenuItem(
                                            text = { Text(p.name) },
                                            onClick = {
                                                items[index] = itemState.copy(
                                                    productId = p.id,
                                                    unitCost = p.buy_price
                                                )
                                                expanded = false
                                            }
                                        )
                                    }
                                }
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                OutlinedTextField(
                                    value = itemState.quantity.toString(),
                                    onValueChange = { qStr ->
                                        val q = qStr.toIntOrNull() ?: 1
                                        items[index] = itemState.copy(quantity = q)
                                    },
                                    label = { Text("Cantidad") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )

                                OutlinedTextField(
                                    value = itemState.unitCost.toString(),
                                    onValueChange = { cStr ->
                                        val c = cStr.toDoubleOrNull() ?: 0.0
                                        items[index] = itemState.copy(unitCost = c)
                                    },
                                    label = { Text("Costo Unitario") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Button(
                    onClick = {
                        viewModel.savePurchaseOrder(
                            supplierName = supplierName,
                            currency = currency,
                            notes = notes,
                            accountId = accountId,
                            items = items,
                            onSaved = onSaved
                        )
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isSaving && accountId.isNotBlank() && items.isNotEmpty() && items.all { it.productId.isNotBlank() }
                ) {
                    if (isSaving) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Text(if (existingPo != null) "Guardar Cambios" else "Crear Orden de Compra")
                    }
                }
            }
        }
    }
}
