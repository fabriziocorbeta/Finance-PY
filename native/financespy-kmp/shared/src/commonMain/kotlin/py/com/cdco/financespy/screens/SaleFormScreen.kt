package py.com.cdco.financespy.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.utils.decodeByteArrayToImageBitmap

@OptIn(ExperimentalMaterial3Api::class)
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
    var showPhotoPreviewDialog by remember { mutableStateOf(false) }

    val decodedBitmap = remember(pendingPhotoBytes) {
        pendingPhotoBytes?.let { decodeByteArrayToImageBitmap(it) }
    }

    var clientName by remember { mutableStateOf("") }
    var currency by remember { mutableStateOf("pyg") }
    var notes by remember { mutableStateOf("") }
    var accountId by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf<SaleFormItemState>() }

    LaunchedEffect(existingSale) {
        existingSale?.let { s ->
            clientName = s.client_name ?: ""
            currency = s.currency
            notes = s.notes ?: ""
            accountId = s.account_id ?: accountId
            items.clear()
            s.sale_items.forEach { item ->
                items.add(
                    SaleFormItemState(
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
                    Text(
                        text = error ?: "",
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }

                OutlinedTextField(
                    value = clientName,
                    onValueChange = { clientName = it },
                    label = { Text("Cliente") },
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
                        text = "Ítems de Venta",
                        style = MaterialTheme.typography.titleMedium,
                        color = FinancePyColors.textPrimary()
                    )

                    IconButton(
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
                                        val q = qStr.toIntOrNull() ?: 1
                                        items[index] = itemState.copy(quantity = q)
                                    },
                                    label = { Text("Cantidad") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )

                                OutlinedTextField(
                                    value = itemState.unitPrice.toString(),
                                    onValueChange = { pStr ->
                                        val p = pStr.toDoubleOrNull() ?: 0.0
                                        items[index] = itemState.copy(unitPrice = p)
                                    },
                                    label = { Text("Precio Unitario") },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                                    modifier = Modifier.weight(1f),
                                    singleLine = true
                                )
                            }
                        }
                    }
                }

                Text(
                    text = "Factura Adjunta",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = FinancePyColors.textPrimary()
                )

                Card(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        val hasPhoto = pendingPhotoName != null || pendingPhotoBytes != null
                        if (hasPhoto) {
                            if (decodedBitmap != null) {
                                Image(
                                    bitmap = decodedBitmap,
                                    contentDescription = "Vista previa de factura",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(180.dp)
                                        .clip(RoundedCornerShape(8.dp))
                                        .clickable { showPhotoPreviewDialog = true }
                                )
                            }
                            if (pendingPhotoName != null) {
                                Text(
                                    text = pendingPhotoName ?: "",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                OutlinedButton(
                                    onClick = {
                                        onTakeInvoicePhoto?.invoke { bytes, name, mime ->
                                            viewModel.onPhotoSelected(bytes, name, mime)
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                    enabled = !isSaving
                                ) {
                                    Text("Tomar otra foto")
                                }
                                OutlinedButton(
                                    onClick = {
                                        onPickInvoicePhoto?.invoke { bytes, name, mime ->
                                            viewModel.onPhotoSelected(bytes, name, mime)
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                    enabled = !isSaving
                                ) {
                                    Text("Cambiar archivo")
                                }
                            }
                            TextButton(
                                onClick = { viewModel.onRemovePhoto() },
                                enabled = !isSaving,
                                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Text("Quitar factura")
                            }
                        } else {
                            Text(
                                text = "Adjuntá una foto o PDF de la factura física",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Button(
                                    onClick = {
                                        onTakeInvoicePhoto?.invoke { bytes, name, mime ->
                                            viewModel.onPhotoSelected(bytes, name, mime)
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                    enabled = !isSaving
                                ) {
                                    Text("Tomar foto")
                                }
                                OutlinedButton(
                                    onClick = {
                                        onPickInvoicePhoto?.invoke { bytes, name, mime ->
                                            viewModel.onPhotoSelected(bytes, name, mime)
                                        }
                                    },
                                    modifier = Modifier.weight(1f),
                                    enabled = !isSaving
                                ) {
                                    Text("Elegir archivo")
                                }
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Button(
                    onClick = {
                        viewModel.saveSale(
                            clientName = clientName,
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
                        Text(if (existingSale != null) "Guardar Cambios" else "Crear Venta")
                    }
                }
            }
        }
    }

    if (showPhotoPreviewDialog && decodedBitmap != null) {
        Dialog(
            onDismissRequest = { showPhotoPreviewDialog = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.9f))
                    .clickable { showPhotoPreviewDialog = false }
                    .padding(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    bitmap = decodedBitmap,
                    contentDescription = "Factura en pantalla completa",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}
