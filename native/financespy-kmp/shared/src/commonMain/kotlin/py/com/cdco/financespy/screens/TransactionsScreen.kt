package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.screens.components.parseHexColor
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionsScreen(
    viewModel: TransactionsViewModel,
    onTransactionClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val state by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()
    var showFilterSheet by remember { mutableStateOf(false) }
    var transactionPendingDelete by remember { mutableStateOf<TransactionListItemDto?>(null) }

    val shouldLoadMore by remember {
        derivedStateOf {
            val layoutInfo = listState.layoutInfo
            val lastVisible = layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: -1
            val totalItems = layoutInfo.totalItemsCount
            totalItems > 0 && lastVisible >= totalItems - 5
        }
    }

    LaunchedEffect(shouldLoadMore, state.hasMorePages, state.isLoadingMore) {
        if (shouldLoadMore && state.hasMorePages && !state.isLoadingMore) {
            viewModel.loadMore()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = state.searchQuery,
                onValueChange = { viewModel.updateSearchQuery(it) },
                placeholder = { Text("Buscar transacciones...") },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Default.Search,
                        contentDescription = null,
                        tint = FinancePyColors.textSecondary()
                    )
                },
                singleLine = true,
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(8.dp)
            )

            IconButton(onClick = { showFilterSheet = true }) {
                Icon(
                    imageVector = Icons.Default.Menu,
                    contentDescription = "Filtrar",
                    tint = FinancePyColors.textPrimary()
                )
            }
        }

        Box(modifier = Modifier.fillMaxSize()) {
            when {
                state.isLoading && state.transactions.isEmpty() -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = FinancePyColors.textPrimary())
                    }
                }
                state.transactions.isEmpty() -> {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(
                            text = "No se encontraron transacciones.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
                else -> {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        items(state.transactions, key = { it.id }) { entry ->
                            TransactionRow(
                                entry = entry,
                                onClick = { onTransactionClick(entry.id) },
                                onEditClick = { onTransactionClick(entry.id) },
                                onDeleteClick = { transactionPendingDelete = entry }
                            )
                        }

                        if (state.isLoadingMore) {
                            item {
                                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(24.dp),
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                            }
                        }
                    }
                }
            }

            val isDark = isSystemInDarkTheme()
            FloatingActionButton(
                onClick = onCreateClick,
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(16.dp),
                containerColor = FinancePyColors.buttonBgPrimary(),
                contentColor = if (isDark) FinancePyColors.Black else FinancePyColors.White
            ) {
                Text(text = "+", style = MaterialTheme.typography.headlineSmall)
            }
        }
    }

    if (showFilterSheet) {
        val sheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            onDismissRequest = { showFilterSheet = false },
            sheetState = sheetState
        ) {
            TransactionFilterSheetContent(
                state = state,
                onApply = { accountId, categoryId, type, startDate, endDate ->
                    viewModel.applyFilters(accountId, categoryId, type, startDate, endDate)
                    showFilterSheet = false
                },
                onClear = {
                    viewModel.clearFilters()
                    showFilterSheet = false
                }
            )
        }
    }

    transactionPendingDelete?.let { entry ->
        AlertDialog(
            onDismissRequest = { transactionPendingDelete = null },
            title = { Text("Eliminar transacción") },
            text = {
                Text("Esto eliminará permanentemente la transacción, afectará tus saldos históricos y no se podrá deshacer.")
            },
            confirmButton = {
                AppButton(
                    text = "Eliminar",
                    variant = ButtonVariant.Destructive,
                    onClick = {
                        viewModel.deleteTransaction(entry.id) {}
                        transactionPendingDelete = null
                    }
                )
            },
            dismissButton = {
                AppButton(
                    text = "Cancelar",
                    variant = ButtonVariant.Secondary,
                    onClick = { transactionPendingDelete = null }
                )
            }
        )
    }
}

@Composable
private fun TransactionRow(
    entry: TransactionListItemDto,
    onClick: () -> Unit,
    onEditClick: () -> Unit,
    onDeleteClick: () -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }

    AppCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically
            ) {
                val dotColor = entry.category?.color?.let { parseHexColor(it) } ?: FinancePyColors.borderSecondary()
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(dotColor)
                )
                Spacer(modifier = Modifier.width(10.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = entry.name,
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )
                    Text(
                        text = entry.date,
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSubdued()
                    )
                    // TransactionListItemDto (the list-row DTO) carries no tags field - only
                    // TransactionDetailDto does - so no tag chips render here on the list screen.
                }
            }

            Spacer(modifier = Modifier.width(8.dp))

            Text(
                text = formatMoney(entry.amount_cents, entry.currency),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = if (entry.classification == "income") FinancePyColors.success() else FinancePyColors.textPrimary()
            )

            Box {
                IconButton(onClick = { showMenu = true }) {
                    Icon(
                        imageVector = Icons.Default.MoreVert,
                        contentDescription = "Más opciones",
                        tint = FinancePyColors.textSecondary()
                    )
                }
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Editar") },
                        onClick = {
                            showMenu = false
                            onEditClick()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Eliminar") },
                        onClick = {
                            showMenu = false
                            onDeleteClick()
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun TransactionFilterSheetContent(
    state: TransactionsUiState,
    onApply: (accountId: String?, categoryId: String?, type: String, startDate: String?, endDate: String?) -> Unit,
    onClear: () -> Unit
) {
    var selectedAccountId by remember(state.selectedAccountId) { mutableStateOf(state.selectedAccountId) }
    var selectedCategoryId by remember(state.selectedCategoryId) { mutableStateOf(state.selectedCategoryId) }
    var selectedType by remember(state.selectedType) { mutableStateOf(state.selectedType) }
    var startDate by remember(state.startDate) { mutableStateOf(state.startDate ?: "") }
    var endDate by remember(state.endDate) { mutableStateOf(state.endDate ?: "") }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Filtrar transacciones",
            style = MaterialTheme.typography.titleLarge,
            color = FinancePyColors.textPrimary()
        )

        AccountDropdownField(
            label = "Cuenta",
            accounts = state.accounts,
            selectedAccountId = selectedAccountId,
            onSelected = { selectedAccountId = it }
        )

        CategoryDropdownField(
            label = "Categoría",
            categories = state.categories,
            selectedCategoryId = selectedCategoryId,
            onSelected = { selectedCategoryId = it }
        )

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "Tipo",
                style = MaterialTheme.typography.labelMedium,
                color = FinancePyColors.textSecondary()
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = selectedType == "all",
                    onClick = { selectedType = "all" },
                    label = { Text("Todas") }
                )
                FilterChip(
                    selected = selectedType == "income",
                    onClick = { selectedType = "income" },
                    label = { Text("Ingreso") }
                )
                FilterChip(
                    selected = selectedType == "expense",
                    onClick = { selectedType = "expense" },
                    label = { Text("Gasto") }
                )
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = startDate,
                onValueChange = { startDate = it },
                label = { Text("Fecha desde") },
                placeholder = { Text("AAAA-MM-DD") },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = endDate,
                onValueChange = { endDate = it },
                label = { Text("Fecha hasta") },
                placeholder = { Text("AAAA-MM-DD") },
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            AppButton(
                text = "Limpiar filtros",
                variant = ButtonVariant.Secondary,
                onClick = onClear,
                modifier = Modifier.weight(1f)
            )
            AppButton(
                text = "Aplicar",
                onClick = {
                    onApply(
                        selectedAccountId,
                        selectedCategoryId,
                        selectedType,
                        startDate.ifBlank { null },
                        endDate.ifBlank { null }
                    )
                },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun AccountDropdownField(
    label: String,
    accounts: List<AccountDto>,
    selectedAccountId: String?,
    onSelected: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedName = accounts.firstOrNull { it.id == selectedAccountId }?.name ?: "Todas las cuentas"

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = FinancePyColors.textSecondary()
        )
        Box {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(FinancePyColors.container())
                    .clickable { expanded = true }
                    .padding(horizontal = 12.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(text = selectedName, color = FinancePyColors.textPrimary())
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(
                    text = { Text("Todas las cuentas") },
                    onClick = {
                        expanded = false
                        onSelected(null)
                    }
                )
                accounts.forEach { account ->
                    DropdownMenuItem(
                        text = { Text(account.name) },
                        onClick = {
                            expanded = false
                            onSelected(account.id)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun CategoryDropdownField(
    label: String,
    categories: List<CategoryDto>,
    selectedCategoryId: String?,
    onSelected: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedCategory = categories.firstOrNull { it.id == selectedCategoryId }

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = FinancePyColors.textSecondary()
        )
        Box {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(FinancePyColors.container())
                    .clickable { expanded = true }
                    .padding(horizontal = 12.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (selectedCategory != null) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(parseHexColor(selectedCategory.color))
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(
                    text = selectedCategory?.name ?: "Todas las categorías",
                    color = FinancePyColors.textPrimary(),
                    modifier = Modifier.weight(1f)
                )
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(
                    text = { Text("Todas las categorías") },
                    onClick = {
                        expanded = false
                        onSelected(null)
                    }
                )
                categories.forEach { category ->
                    DropdownMenuItem(
                        text = {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .clip(CircleShape)
                                        .background(parseHexColor(category.color))
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(category.name)
                            }
                        },
                        onClick = {
                            expanded = false
                            onSelected(category.id)
                        }
                    )
                }
            }
        }
    }
}
