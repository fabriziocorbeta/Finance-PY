package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.InvoicePhotoSectionCard
import py.com.cdco.financespy.theme.components.ZoomableInvoicePhotoDialog
import py.com.cdco.financespy.theme.components.liquidGlass
import py.com.cdco.financespy.utils.decodeByteArrayToImageBitmap
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SaleDetailScreen(
    viewModel: SaleDetailViewModel,
    onEditClick: () -> Unit,
    onDeleted: () -> Unit,
    onBack: () -> Unit,
    onPickInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null,
    onTakeInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null
) {
    val saleState by viewModel.sale.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isActioning by viewModel.isActioning.collectAsState()
    val invoicePhotoBytes by viewModel.invoicePhotoBytes.collectAsState()
    val isUploadingPhoto by viewModel.isUploadingPhoto.collectAsState()
    val error by viewModel.error.collectAsState()

    var showCompleteDialog by remember { mutableStateOf(false) }
    var showCancelDialog by remember { mutableStateOf(false) }
    var showDeleteSaleDialog by remember { mutableStateOf(false) }
    var showDeletePhotoDialog by remember { mutableStateOf(false) }
    var showPhotoPreviewDialog by remember { mutableStateOf(false) }

    val decodedBitmap = remember(invoicePhotoBytes) {
        invoicePhotoBytes?.let { decodeByteArrayToImageBitmap(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(saleState?.let { "Venta #${it.sale_number ?: ""}" } ?: "Detalle de Venta") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver")
                    }
                },
                actions = {
                    if (saleState?.status == "draft") {
                        IconButton(onClick = onEditClick) {
                            Icon(Icons.Default.Edit, contentDescription = "Editar")
                        }
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
        val sale = saleState
        when {
            isLoading && sale == null -> {
                Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
            }
            sale != null -> {
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

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Estado",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )

                                val (statusText, statusContainerColor, statusContentColor) = when (sale.status) {
                                    "completed" -> Triple("Completada", MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.onPrimaryContainer)
                                    "cancelled" -> Triple("Cancelada", MaterialTheme.colorScheme.errorContainer, MaterialTheme.colorScheme.onErrorContainer)
                                    else -> Triple("Borrador", MaterialTheme.colorScheme.surfaceVariant, MaterialTheme.colorScheme.onSurfaceVariant)
                                }

                                Surface(
                                    color = statusContainerColor,
                                    shape = RoundedCornerShape(4.dp)
                                ) {
                                    Text(
                                        text = statusText,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = statusContentColor,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            }

                            if (!sale.client_name.isNullOrBlank()) {
                                SaleDetailMetadataRow("Cliente", sale.client_name)
                            }
                            if (!sale.invoice_number.isNullOrBlank()) {
                                SaleDetailMetadataRow("N° de Factura", sale.invoice_number)
                            }
                            if (!sale.condition.isNullOrBlank()) {
                                SaleDetailMetadataRow("Condición", sale.condition.replaceFirstChar { it.uppercase() })
                            }
                            if (!sale.payment_method.isNullOrBlank()) {
                                SaleDetailMetadataRow("Método de pago", sale.payment_method)
                            }
                            SaleDetailMetadataRow("Moneda", sale.currency.uppercase())
                            if (!sale.delivery_address.isNullOrBlank()) {
                                SaleDetailMetadataRow("Dirección entrega", sale.delivery_address)
                            }
                            if (!sale.delivery_date.isNullOrBlank()) {
                                SaleDetailMetadataRow("Fecha entrega", sale.delivery_date)
                            }
                            if (!sale.carrier.isNullOrBlank()) {
                                SaleDetailMetadataRow("Transportadora", sale.carrier)
                            }
                            if (!sale.created_at.isNullOrBlank()) {
                                SaleDetailMetadataRow("Creada", sale.created_at.take(10))
                            }
                            if (!sale.notes.isNullOrBlank()) {
                                SaleDetailMetadataRow("Notas", sale.notes)
                            }

                            Spacer(modifier = Modifier.height(4.dp))
                            HorizontalDivider(color = FinancePyColors.surface())
                            Spacer(modifier = Modifier.height(4.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween
                            ) {
                                Text(
                                    text = "Total",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = FinancePyColors.textPrimary()
                                )
                                Text(
                                    text = formatMoney(sale.total, sale.currency.uppercase()),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = FinancePyColors.textPrimary()
                                )
                            }
                        }
                    }

                    Text(
                        text = "Ítems (${sale.sale_items.size})",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = FinancePyColors.textPrimary()
                    )

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                    ) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            sale.sale_items.forEach { item ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = item.product_name ?: "Producto",
                                            style = MaterialTheme.typography.bodyMedium,
                                            fontWeight = FontWeight.SemiBold,
                                            color = FinancePyColors.textPrimary()
                                        )
                                        Text(
                                            text = "${item.quantity} x ${formatMoney(item.unit_price, sale.currency.uppercase())}",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = FinancePyColors.textSecondary()
                                        )
                                    }
                                    Text(
                                        text = formatMoney(item.subtotal, sale.currency.uppercase()),
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = FinancePyColors.textPrimary()
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

                    val invoicePhoto = sale.invoice_photo
                    val hasPhoto = sale.has_invoice_photo || invoicePhoto != null
                    InvoicePhotoSectionCard(
                        hasAttachment = hasPhoto,
                        decodedBitmap = decodedBitmap,
                        fileName = invoicePhoto?.filename,
                        contentType = invoicePhoto?.content_type,
                        byteSize = invoicePhoto?.byte_size,
                        isProcessing = isUploadingPhoto,
                        emptyPrompt = "Adjuntá una foto o PDF de la factura física",
                        removeLabel = "Eliminar factura",
                        onTakePhoto = onTakeInvoicePhoto?.let { launcher ->
                            {
                                launcher { bytes, name, mime ->
                                    viewModel.uploadInvoicePhoto(bytes, name, mime)
                                }
                            }
                        },
                        onPickFile = onPickInvoicePhoto?.let { launcher ->
                            {
                                launcher { bytes, name, mime ->
                                    viewModel.uploadInvoicePhoto(bytes, name, mime)
                                }
                            }
                        },
                        onRemove = { showDeletePhotoDialog = true },
                        onPreviewClick = { if (decodedBitmap != null) showPhotoPreviewDialog = true }
                    )

                    Spacer(modifier = Modifier.height(8.dp))
                    when (sale.status) {
                        "draft" -> {
                            Button(
                                onClick = { showCompleteDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning && sale.sale_items.isNotEmpty(),
                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                            ) {
                                Text("Completar Venta")
                            }

                            OutlinedButton(
                                onClick = { showCancelDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning,
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Text("Cancelar Venta")
                            }

                            TextButton(
                                onClick = { showDeleteSaleDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning,
                                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("Eliminar Borrador")
                            }
                        }
                        "completed" -> {
                            OutlinedButton(
                                onClick = { showCancelDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning,
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Text("Cancelar Venta (Devolver Stock)")
                            }
                        }
                    }
                }
            }
        }
    }

    if (showPhotoPreviewDialog && decodedBitmap != null) {
        ZoomableInvoicePhotoDialog(
            bitmap = decodedBitmap,
            title = saleState?.invoice_photo?.filename ?: "Factura de venta",
            onDismiss = { showPhotoPreviewDialog = false }
        )
    }

    if (showDeletePhotoDialog) {
        AlertDialog(
            modifier = Modifier.liquidGlass(RoundedCornerShape(28.dp)),
            containerColor = Color.Transparent,
            onDismissRequest = { showDeletePhotoDialog = false },
            title = { Text("Eliminar factura") },
            text = { Text("¿Deseas eliminar la factura adjunta?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeletePhotoDialog = false
                        viewModel.deleteInvoicePhoto()
                    }
                ) {
                    Text("Eliminar", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeletePhotoDialog = false }) {
                    Text("Cancelar")
                }
            }
        )
    }

    if (showDeleteSaleDialog) {
        AlertDialog(
            modifier = Modifier.liquidGlass(RoundedCornerShape(28.dp)),
            containerColor = Color.Transparent,
            onDismissRequest = { showDeleteSaleDialog = false },
            title = { Text("Eliminar Borrador") },
            text = { Text("¿Deseas eliminar permanentemente esta venta en borrador?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteSaleDialog = false
                        viewModel.deleteSale(onDeleted)
                    }
                ) {
                    Text("Eliminar", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteSaleDialog = false }) {
                    Text("Cancelar")
                }
            }
        )
    }

    if (showCompleteDialog) {
        AlertDialog(
            modifier = Modifier.liquidGlass(RoundedCornerShape(28.dp)),
            containerColor = Color.Transparent,
            onDismissRequest = { showCompleteDialog = false },
            title = { Text("Completar Venta") },
            text = { Text("¿Deseas completar esta venta? Se descontará el stock de los productos.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showCompleteDialog = false
                        viewModel.completeSale()
                    }
                ) {
                    Text("Completar")
                }
            },
            dismissButton = {
                TextButton(onClick = { showCompleteDialog = false }) {
                    Text("Volver")
                }
            }
        )
    }

    if (showCancelDialog) {
        AlertDialog(
            modifier = Modifier.liquidGlass(RoundedCornerShape(28.dp)),
            containerColor = Color.Transparent,
            onDismissRequest = { showCancelDialog = false },
            title = { Text("Cancelar Venta") },
            text = {
                Text(
                    if (saleState?.status == "completed")
                        "¿Deseas cancelar esta venta completada? Se revertirá el stock de los productos."
                    else
                        "¿Deseas cancelar esta venta en borrador?"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showCancelDialog = false
                        viewModel.cancelSale()
                    }
                ) {
                    Text("Confirmar Cancelación", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showCancelDialog = false }) {
                    Text("Volver")
                }
            }
        )
    }
}

@Composable
private fun SaleDetailMetadataRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = FinancePyColors.textSecondary(),
            modifier = Modifier.weight(0.4f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = FinancePyColors.textPrimary(),
            modifier = Modifier.weight(0.6f)
        )
    }
}
