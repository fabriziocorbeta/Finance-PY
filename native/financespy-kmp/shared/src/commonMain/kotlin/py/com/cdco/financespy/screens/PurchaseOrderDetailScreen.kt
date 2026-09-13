package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.PurchaseOrderDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PurchaseOrderDetailScreen(
    viewModel: PurchaseOrderDetailViewModel,
    onEditClick: () -> Unit,
    onDeleted: () -> Unit,
    onBack: () -> Unit
) {
    val poState by viewModel.purchaseOrder.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val isActioning by viewModel.isActioning.collectAsState()
    val error by viewModel.error.collectAsState()

    var showReceiveDialog by remember { mutableStateOf(false) }
    var showCancelDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(poState?.let { "Orden #${it.order_number ?: ""}" } ?: "Detalle de Orden") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Volver")
                    }
                },
                actions = {
                    if (poState?.status == "draft") {
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
        val po = poState
        when {
            isLoading && po == null -> {
                Box(modifier = Modifier.fillMaxSize().padding(padding)) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
            }
            po != null -> {
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

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
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

                                val (statusText, statusContainerColor, statusContentColor) = when (po.status) {
                                    "received" -> Triple("Recibida", MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.onPrimaryContainer)
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

                            if (!po.supplier_name.isNullOrBlank()) {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "Proveedor: ${po.supplier_name}",
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontWeight = FontWeight.SemiBold,
                                    color = FinancePyColors.textPrimary()
                                )
                            }

                            Spacer(modifier = Modifier.height(12.dp))
                            HorizontalDivider(color = FinancePyColors.surface())
                            Spacer(modifier = Modifier.height(12.dp))

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
                                    text = formatMoney(po.total, po.currency.uppercase()),
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = FinancePyColors.textPrimary()
                                )
                            }
                        }
                    }

                    Text(
                        text = "Ítems",
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
                            po.purchase_order_items.forEach { item ->
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
                                            text = "${item.quantity} x ${formatMoney(item.unit_cost, po.currency.uppercase())}",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = FinancePyColors.textSecondary()
                                        )
                                    }
                                    Text(
                                        text = formatMoney(item.subtotal, po.currency.uppercase()),
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(8.dp))
                    when (po.status) {
                        "draft" -> {
                            Button(
                                onClick = { showReceiveDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning && po.purchase_order_items.isNotEmpty(),
                                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                            ) {
                                Text("Recibir Orden")
                            }

                            OutlinedButton(
                                onClick = { showCancelDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning,
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Text("Cancelar Orden")
                            }
                        }
                        "received" -> {
                            OutlinedButton(
                                onClick = { showCancelDialog = true },
                                modifier = Modifier.fillMaxWidth(),
                                enabled = !isActioning,
                                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
                            ) {
                                Text("Cancelar Orden (Devolver Stock)")
                            }
                        }
                    }
                }
            }
        }
    }

    if (showReceiveDialog) {
        AlertDialog(
            onDismissRequest = { showReceiveDialog = false },
            title = { Text("Recibir Orden de Compra") },
            text = { Text("¿Deseas marcar como recibida esta orden? Se incrementará el stock de los productos.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showReceiveDialog = false
                        viewModel.receivePurchaseOrder()
                    }
                ) {
                    Text("Recibir")
                }
            },
            dismissButton = {
                TextButton(onClick = { showReceiveDialog = false }) {
                    Text("Volver")
                }
            }
        )
    }

    if (showCancelDialog) {
        AlertDialog(
            onDismissRequest = { showCancelDialog = false },
            title = { Text("Cancelar Orden de Compra") },
            text = {
                Text(
                    if (poState?.status == "received")
                        "¿Deseas cancelar esta orden recibida? Se revertirá la entrada de stock de los productos."
                    else
                        "¿Deseas cancelar esta orden en borrador?"
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showCancelDialog = false
                        viewModel.cancelPurchaseOrder()
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
