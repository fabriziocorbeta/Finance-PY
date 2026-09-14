package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
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
fun PurchaseOrdersListScreen(
    viewModel: PurchaseOrdersListViewModel,
    onPurchaseOrderClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val purchaseOrders by viewModel.purchaseOrders.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val error by viewModel.error.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

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
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(purchaseOrders, key = { it.id }) { po ->
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
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Proveedor: ${po.supplier_name}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textSecondary()
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

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
