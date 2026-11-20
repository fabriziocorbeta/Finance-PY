package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.PurchaseOrderDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppBottomNavOverlayClearance
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PurchaseOrdersListScreen(
    viewModel: PurchaseOrdersListViewModel,
    onPurchaseOrderClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val purchaseOrders by viewModel.purchaseOrders.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()

    var searchQuery by remember { mutableStateOf("") }
    var selectedStatus by remember { mutableStateOf("all") }

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    val filteredOrders = remember(purchaseOrders, searchQuery, selectedStatus) {
        purchaseOrders.filter { po ->
            val matchesStatus = selectedStatus == "all" || po.status == selectedStatus
            val q = searchQuery.trim().lowercase()
            val matchesQuery = q.isEmpty() ||
                (po.order_number?.toString()?.contains(q) == true) ||
                (po.supplier_name?.lowercase()?.contains(q) == true) ||
                (po.notes?.lowercase()?.contains(q) == true)
            matchesStatus && matchesQuery
        }
    }

    val draftCount = purchaseOrders.count { it.status == "draft" }
    val receivedCount = purchaseOrders.count { it.status == "received" }
    val withInvoiceCount = purchaseOrders.count { it.has_invoice_photo || it.invoice_photo != null }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Órdenes de Compra", style = MaterialTheme.typography.titleLarge) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FinancePyColors.container(),
                    titleContentColor = FinancePyColors.textPrimary()
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onCreateClick,
                modifier = Modifier.padding(bottom = AppBottomNavOverlayClearance),
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            ) {
                Icon(Icons.Default.Add, contentDescription = "Nueva Orden")
            }
        },
        containerColor = FinancePyColors.surface()
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                isLoading && purchaseOrders.isEmpty() -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                error != null && purchaseOrders.isEmpty() -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = error ?: "Error",
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodyMedium
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = { viewModel.refresh() }) {
                            Text("Reintentar")
                        }
                    }
                }
                purchaseOrders.isEmpty() -> {
                    Text(
                        text = "No hay órdenes de compra registradas",
                        modifier = Modifier.align(Alignment.Center),
                        style = MaterialTheme.typography.bodyLarge,
                        color = FinancePyColors.textSecondary()
                    )
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(start = 16.dp, top = 12.dp, end = 16.dp, bottom = AppBottomNavOverlayClearance),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                PurchaseSummaryMetricCard(
                                    label = "Total",
                                    value = purchaseOrders.size.toString(),
                                    modifier = Modifier.weight(1f)
                                )
                                PurchaseSummaryMetricCard(
                                    label = "Borradores",
                                    value = draftCount.toString(),
                                    modifier = Modifier.weight(1f)
                                )
                                PurchaseSummaryMetricCard(
                                    label = "Con factura",
                                    value = "$withInvoiceCount/${purchaseOrders.size}",
                                    modifier = Modifier.weight(1f)
                                )
                            }
                        }

                        item {
                            OutlinedTextField(
                                value = searchQuery,
                                onValueChange = { searchQuery = it },
                                placeholder = { Text("Buscar por #orden, proveedor o nota") },
                                leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                                trailingIcon = {
                                    if (searchQuery.isNotEmpty()) {
                                        IconButton(onClick = { searchQuery = "" }) {
                                            Icon(Icons.Default.Close, contentDescription = "Limpiar")
                                        }
                                    }
                                },
                                singleLine = true,
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(12.dp)
                            )
                        }

                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .horizontalScroll(rememberScrollState()),
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                listOf(
                                    "all" to "Todas (${purchaseOrders.size})",
                                    "draft" to "Borrador ($draftCount)",
                                    "received" to "Recibidas ($receivedCount)",
                                    "cancelled" to "Canceladas"
                                ).forEach { (statusKey, label) ->
                                    FilterChip(
                                        selected = selectedStatus == statusKey,
                                        onClick = { selectedStatus = statusKey },
                                        label = { Text(label) }
                                    )
                                }
                            }
                        }

                        if (filteredOrders.isEmpty()) {
                            item {
                                Text(
                                    text = "No se encontraron órdenes con ese filtro",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary(),
                                    modifier = Modifier.padding(vertical = 24.dp)
                                )
                            }
                        } else {
                            items(filteredOrders, key = { it.id }) { po ->
                                PurchaseOrderItemCard(
                                    po = po,
                                    onClick = { onPurchaseOrderClick(po.id) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PurchaseSummaryMetricCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = FinancePyColors.textPrimary(),
                maxLines = 1
            )
        }
    }
}

@Composable
private fun PurchaseOrderItemCard(
    po: PurchaseOrderDto,
    onClick: () -> Unit
) {
    val (statusText, statusContainerColor, statusContentColor) = when (po.status) {
        "received" -> Triple("Recibida", MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.onPrimaryContainer)
        "cancelled" -> Triple("Cancelada", MaterialTheme.colorScheme.errorContainer, MaterialTheme.colorScheme.onErrorContainer)
        else -> Triple("Borrador", MaterialTheme.colorScheme.surfaceVariant, MaterialTheme.colorScheme.onSurfaceVariant)
    }

    val hasInvoice = po.has_invoice_photo || po.invoice_photo != null

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Orden #${po.order_number ?: ""}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = FinancePyColors.textPrimary()
                )

                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (hasInvoice) {
                        Surface(
                            color = MaterialTheme.colorScheme.secondaryContainer,
                            shape = RoundedCornerShape(4.dp)
                        ) {
                            Row(
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(3.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.ReceiptLong,
                                    contentDescription = "Factura adjunta",
                                    tint = MaterialTheme.colorScheme.onSecondaryContainer,
                                    modifier = Modifier.size(12.dp)
                                )
                                Text(
                                    text = "Factura",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                            }
                        }
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
            }

            if (!po.supplier_name.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Proveedor: ${po.supplier_name}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textSecondary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }

            val dateLabel = po.expected_date ?: po.created_at?.take(10)
            if (!dateLabel.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = if (po.expected_date != null) "Esperada: $dateLabel" else "Fecha: $dateLabel",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
                )
            }

            Spacer(modifier = Modifier.height(10.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${po.purchase_order_items.size} ítems",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
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
}
