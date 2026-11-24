package py.com.cdco.financespy.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
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

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SaleFormScreen(
    viewModel: SaleFormViewModel,
    onSaved: () -> Unit,
    onCancel: () -> Unit,
    onPickInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null,
    onTakeInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null
) {
    val existingSale by viewModel.sale.collectAsState()
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

    var clientName by remember { mutableStateOf("") }
    var currency by remember { mutableStateOf("pyg") }
    var invoiceNumber by remember { mutableStateOf("") }
    var condition by remember { mutableStateOf("contado") }
    var paymentMethod by remember { mutableStateOf("Efectivo") }
    var notes by remember { mutableStateOf("") }
    var deliveryAddress by remember { mutableStateOf("") }
    var deliveryDate by remember { mutableStateOf("") }
    var carrier by remember { mutableStateOf("") }
    var showDeliverySection by remember { mutableStateOf(false) }
    var accountId by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf<SaleFormItemState>() }

    LaunchedEffect(existingSale) {
        existingSale?.let { s ->
            clientName = s.client_name ?: ""
            currency = s.currency
            invoiceNumber = s.invoice_number ?: ""
            condition = s.condition ?: "contado"
            paymentMethod = s.payment_method ?: ""
            notes = s.notes ?: ""
            deliveryAddress = s.delivery_address ?: ""
            deliveryDate = s.delivery_date ?: ""
            carrier = s.carrier ?: ""
            if (!s.delivery_address.isNullOrBlank() || !s.delivery_date.isNullOrBlank() || !s.carrier.isNullOrBlank()) {
                showDeliverySection = true
            }
            accountId = s.account_id ?: accountId
            items.clear()
            s.sale_items.forEach { item ->
                items.add(
                    SaleFormItemState(
                        existingId = item.id,
                        productId = item.product_id,
                        quantity = item.quantity,
                        unitPrice = item.unit_price
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

    LaunchedEffect(availableProducts, existingSale) {
        if (existingSale == null && items.isEmpty() && availableProducts.isNotEmpty()) {
            val firstProduct = availableProducts.first()
            items.add(
                SaleFormItemState(
                    productId = firstProduct.id,
                    quantity = 1,
                    unitPrice = firstProduct.sell_price
                )
            )
        }
    }

    val saleTotal = items.sumOf { it.quantity.coerceAtLeast(0) * it.unitPrice }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        if (existingSale != null) "Editar Venta" else "Nueva Venta",
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
                    value = clientName,
                    onValueChange = { clientName = it },
                    label = { Text("Cliente") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )

                OutlinedTextField(
                    value = invoiceNumber,
                    onValueChange = { invoiceNumber = it },
                    label = { Text("Número de factura (opcional)") },
                    placeholder = { Text("001-001-0001234") },
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

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "Condición de venta",
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary()
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("contado" to "Contado", "credito" to "Crédito").forEach { (value, label) ->
                            FilterChip(
                                selected = condition.equals(value, ignoreCase = true),
                                onClick = { condition = value },
                                label = { Text(label) }
                            )
                        }
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "Método de pago",
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary()
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        listOf("Efectivo", "Transferencia", "Tarjeta", "QR", "Cheque").forEach { method ->
                            FilterChip(
                                selected = paymentMethod.equals(method, ignoreCase = true),
                                onClick = { paymentMethod = method },
                                label = { Text(method) }
                            )
                        }
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

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                ) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        TextButton(
                            onClick = { showDeliverySection = !showDeliverySection },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("Datos de envío / entrega (opcional)")
                                Icon(
                                    imageVector = if (showDeliverySection) Icons.Default.ExpandLess else Icons.Default.ExpandMore,
                                    contentDescription = null
                                )
                            }
                        }

                        AnimatedVisibility(visible = showDeliverySection) {
                            Column(
                                modifier = Modifier.padding(top = 8.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp)
                            ) {
                                OutlinedTextField(
                                    value = deliveryAddress,
                                    onValueChange = { deliveryAddress = it },
                                    label = { Text("Dirección de entrega") },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    OutlinedTextField(
                                        value = deliveryDate,
                                        onValueChange = { deliveryDate = it },
                                        label = { Text("Fecha de entrega (YYYY-MM-DD)") },
                                        modifier = Modifier.weight(1f),
                                        singleLine = true
                                    )
                                    OutlinedButton(onClick = { deliveryDate = currentIsoDate() }) {
                                        Text("Hoy")
                                    }
                                }
                                OutlinedTextField(
                                    value = carrier,
                                    onValueChange = { carrier = it },
                                    label = { Text("Transportadora / Chofer") },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
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
                        text = "Ítems de Venta",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = FinancePyColors.textPrimary()
                    )

                    FilledTonalButton(
                        onClick = {
                            val firstProduct = availableProducts.firstOrNull()
                            items.add(
                                SaleFormItemState(
                                    productId = firstProduct?.id ?: "",
                                    quantity = 1,
                                    unitPrice = firstProduct?.sell_price ?: 0.0
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
                                        text = formatMoney(itemState.quantity.coerceAtLeast(0) * itemState.unitPrice, currency.uppercase()),
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
                                                    unitPrice = p.sell_price
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
                                    value = if (itemState.unitPrice == 0.0) "" else itemState.unitPrice.toString(),
                                    onValueChange = { pStr ->
                                        val p = py.com.cdco.financespy.utils.AmountParser.parse(pStr, currency) ?: 0.0
                                        items[index] = itemState.copy(unitPrice = p)
                                    },
                                    label = { Text("Precio Unitario") },
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
                            text = "Total de la Venta",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = formatMoney(saleTotal, currency.uppercase()),
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = FinancePyColors.textPrimary()
                        )
                    }
                }

                Text(
                    text = "Factura Adjunta",
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
                    emptyPrompt = "Adjuntá una foto o PDF de la factura física",
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
                        viewModel.saveSale(
                            clientName = clientName,
                            currency = currency,
                            paymentMethod = paymentMethod,
                            invoiceNumber = invoiceNumber,
                            condition = condition,
                            notes = notes,
                            deliveryAddress = deliveryAddress,
                            deliveryDate = deliveryDate,
                            carrier = carrier,
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
                        Text(if (existingSale != null) "Guardar Cambios" else "Crear Venta")
                    }
                }
            }
        }
    }

    if (showPhotoPreviewDialog && decodedBitmap != null) {
        ZoomableInvoicePhotoDialog(
            bitmap = decodedBitmap,
            title = pendingPhotoName ?: "Factura de venta",
            onDismiss = { showPhotoPreviewDialog = false }
        )
    }
}
