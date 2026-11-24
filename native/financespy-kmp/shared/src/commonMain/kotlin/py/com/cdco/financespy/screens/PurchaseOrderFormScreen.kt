package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.sync.currentIsoDate
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.InvoicePhotoSectionCard
import py.com.cdco.financespy.theme.components.ZoomableInvoicePhotoDialog
import py.com.cdco.financespy.utils.decodeByteArrayToImageBitmap
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PurchaseOrderFormScreen(
    viewModel: PurchaseOrderFormViewModel,
    onSaved: () -> Unit,
    onCancel: () -> Unit,
    onPickInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null,
    onTakeInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null
) {
    val existingPo by viewModel.purchaseOrder.collectAsState()
    val availableProducts by viewModel.availableProducts.collectAsState()
    val availableAccounts by viewModel.availableAccounts.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isSaving by viewModel.isSaving.collectAsState()
    val error by viewModel.error.collectAsState()
    val pendingPhotoBytes by viewModel.pendingPhotoBytes.collectAsState()
    val pendingPhotoName by viewModel.pendingPhotoName.collectAsState()
    val pendingPhotoContentType by viewModel.pendingPhotoContentType.collectAsState()
    var showPhotoPreviewDialog by remember { mutableStateOf(false) }

    val decodedBitmap = remember(pendingPhotoBytes) {
        pendingPhotoBytes?.let { decodeByteArrayToImageBitmap(it) }
    }

    var supplierName by remember { mutableStateOf("") }
    var currency by remember { mutableStateOf("pyg") }
    var expectedDate by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    var accountId by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf<PurchaseOrderFormItemState>() }

    LaunchedEffect(existingPo) {
        existingPo?.let { po ->
            supplierName = po.supplier_name ?: ""
            currency = po.currency
            expectedDate = po.expected_date ?: ""
            notes = po.notes ?: ""
            accountId = po.account_id ?: accountId
            items.clear()
            po.purchase_order_items.forEach { item ->
                items.add(
                    PurchaseOrderFormItemState(
                        existingId = item.id,
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

    LaunchedEffect(availableProducts, existingPo) {
        if (existingPo == null && items.isEmpty() && availableProducts.isNotEmpty()) {
            val firstProduct = availableProducts.first()
            items.add(
                PurchaseOrderFormItemState(
                    productId = firstProduct.id,
                    quantity = 1,
                    unitCost = firstProduct.buy_price
                )
            )
        }
    }

    val orderTotal = items.sumOf { it.quantity.coerceAtLeast(0) * it.unitCost }

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
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver")
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
                    Surface(
                        color = MaterialTheme.colorScheme.errorContainer,
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = error ?: "",
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(12.dp)
                        )
                    }
                }

                OutlinedTextField(
                    value = supplierName,
                    onValueChange = { supplierName = it },
                    label = { Text("Proveedor") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "Moneda",
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary()
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("pyg" to "PYG (Guaraníes)", "usd" to "USD (Dólares)").forEach { (code, label) ->
                            FilterChip(
                                selected = currency.equals(code, ignoreCase = true),
                                onClick = { currency = code },
                                label = { Text(label) }
                            )
                        }
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedTextField(
                        value = expectedDate,
                        onValueChange = { expectedDate = it },
                        label = { Text("Fecha esperada (YYYY-MM-DD)") },
                        placeholder = { Text("2026-11-20") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    OutlinedButton(onClick = { expectedDate = currentIsoDate() }) {
                        Text("Hoy")
                    }
                }

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

                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notas") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Ítems de Orden",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = FinancePyColors.textPrimary()
                    )

                    FilledTonalButton(
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
                        Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("Agregar ítem")
                    }
                }

                items.forEachIndexed { index, itemState ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
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
                                Text(
                                    text = "Ítem ${index + 1}",
                                    style = MaterialTheme.typography.labelLarge,
                                    color = FinancePyColors.textSecondary()
                                )
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = formatMoney(itemState.quantity.coerceAtLeast(0) * itemState.unitCost, currency.uppercase()),
                                        style = MaterialTheme.typography.labelLarge,
                                        fontWeight = FontWeight.Bold,
                                        color = FinancePyColors.textPrimary()
                                    )
                                    IconButton(onClick = { items.removeAt(index) }) {
                                        Icon(Icons.Default.Delete, contentDescription = "Quitar ítem", tint = MaterialTheme.colorScheme.error)
                                    }
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
                                            text = { Text("${p.name} (Stock: ${p.stock})") },
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
                                        val q = qStr.toIntOrNull()?.coerceAtLeast(1) ?: 1
                                        items[index] = itemState.copy(quantity = q)
                                    },
                                    label = { Text("Cantidad") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )

                                OutlinedTextField(
                                    value = if (itemState.unitCost == 0.0) "" else itemState.unitCost.toString(),
                                    onValueChange = { cStr ->
                                        val c = py.com.cdco.financespy.utils.AmountParser.parse(cStr, currency) ?: 0.0
                                        items[index] = itemState.copy(unitCost = c)
                                    },
                                    label = { Text("Costo Unitario") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                            }
                        }
                    }
                }

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Total de la Orden",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = formatMoney(orderTotal, currency.uppercase()),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = FinancePyColors.textPrimary()
                        )
                    }
                }

                Text(
                    text = "Factura de Compra Adjunta",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = FinancePyColors.textPrimary()
                )

                val hasPhoto = pendingPhotoName != null || pendingPhotoBytes != null
                InvoicePhotoSectionCard(
                    hasAttachment = hasPhoto,
                    decodedBitmap = decodedBitmap,
                    fileName = pendingPhotoName,
                    contentType = pendingPhotoContentType,
                    byteSize = pendingPhotoBytes?.size?.toLong(),
                    isProcessing = isSaving,
                    emptyPrompt = "Adjuntá una foto o PDF de la factura de compra",
                    removeLabel = "Quitar factura",
                    onTakePhoto = onTakeInvoicePhoto?.let { launcher ->
                        {
                            launcher { bytes, name, mime ->
                                viewModel.onPhotoSelected(bytes, name, mime)
                            }
                        }
                    },
                    onPickFile = onPickInvoicePhoto?.let { launcher ->
                        {
                            launcher { bytes, name, mime ->
                                viewModel.onPhotoSelected(bytes, name, mime)
                            }
                        }
                    },
                    onRemove = { viewModel.onRemovePhoto() },
                    onPreviewClick = { if (decodedBitmap != null) showPhotoPreviewDialog = true }
                )

                Spacer(modifier = Modifier.height(8.dp))

                Button(
                    onClick = {
                        viewModel.savePurchaseOrder(
                            supplierName = supplierName,
                            currency = currency,
                            expectedDate = expectedDate,
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

    if (showPhotoPreviewDialog && decodedBitmap != null) {
        ZoomableInvoicePhotoDialog(
            bitmap = decodedBitmap,
            title = pendingPhotoName ?: "Factura de compra",
            onDismiss = { showPhotoPreviewDialog = false }
        )
    }
}
