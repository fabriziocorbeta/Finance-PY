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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.screens.components.parseHexColor
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppBottomNavOverlayClearance
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppGroupedListCard
import py.com.cdco.financespy.theme.components.AppSearchField
import py.com.cdco.financespy.theme.components.AppSegmentedControl
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.theme.components.iosLiquidGlass
import py.com.cdco.financespy.theme.components.liquidGlass
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionsScreen(
    viewModel: TransactionsViewModel,
    onTransactionClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val variant = LocalUiVariant.current
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

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = FinancePyColors.surface()
    ) {
        if (variant == UiVariant.IOS) {
        IosTransactionsContent(
            state = state,
            listState = listState,
            onSearchQueryChange = { viewModel.updateSearchQuery(it) },
            onSelectAccount = { accountId ->
                viewModel.applyFilters(
                    accountId = accountId,
                    categoryId = state.selectedCategoryId,
                    type = state.selectedType,
                    startDate = state.startDate,
                    endDate = state.endDate
                )
            },
            onSelectType = { type ->
                viewModel.applyFilters(
                    accountId = state.selectedAccountId,
                    categoryId = state.selectedCategoryId,
                    type = type,
                    startDate = state.startDate,
                    endDate = state.endDate
                )
            },
            onOpenFilters = { showFilterSheet = true },
            onTransactionClick = onTransactionClick,
            onDeleteClick = { transactionPendingDelete = it },
            onCreateClick = onCreateClick
        )
    } else {
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
                            contentDescription = "Buscar",
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

            if (state.isOffline) {
                Text(
                    text = "Sin conexión: mostrando datos guardados (últimos 90 días)",
                    style = MaterialTheme.typography.labelMedium,
                    color = FinancePyColors.textSecondary(),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
                )
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
                            contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = AppBottomNavOverlayClearance),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            items(state.transactions, key = { it.id }) { entry ->
                                TransactionRow(
                                    entry = entry,
                                    onClick = { if (!entry.pending) onTransactionClick(entry.id) },
                                    onEditClick = { if (!entry.pending) onTransactionClick(entry.id) },
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
                        .padding(bottom = AppBottomNavOverlayClearance, end = 16.dp, top = 16.dp, start = 16.dp),
                    containerColor = FinancePyColors.buttonBgPrimary(),
                    contentColor = if (isDark) FinancePyColors.Black else FinancePyColors.White
                ) {
                    Text(text = "+", style = MaterialTheme.typography.headlineSmall)
                }
            }
        }
    }
    }

    if (showFilterSheet) {
        val sheetState = rememberModalBottomSheetState()
        ModalBottomSheet(
            containerColor = Color.Transparent,
            modifier = if (variant == UiVariant.IOS) {
                Modifier.iosLiquidGlass(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp), contrastBoost = 0.15f)
            } else {
                Modifier.liquidGlass(RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp))
            },
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
            modifier = if (variant == UiVariant.IOS) {
                Modifier.iosLiquidGlass(RoundedCornerShape(20.dp))
            } else {
                Modifier.liquidGlass(RoundedCornerShape(28.dp))
            },
            containerColor = Color.Transparent,
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

// Variante iOS (Apple HIG + paridad visual con TransactionsView.swift de
// financespy-ios): barra de navegación con selector de cuenta estilo Menu
// Picker y acción "+" en la esquina superior derecha (sin FAB flotante),
// Large Title "Transacciones" de 34sp, barra de búsqueda estilo .searchable,
// control segmentado Todas/Ingresos/Gastos y lista agrupada por fecha con
// contenedores Inset Grouped de 10dp y separadores hairline.
@Composable
private fun IosTransactionsContent(
    state: TransactionsUiState,
    listState: LazyListState,
    onSearchQueryChange: (String) -> Unit,
    onSelectAccount: (String?) -> Unit,
    onSelectType: (String) -> Unit,
    onOpenFilters: () -> Unit,
    onTransactionClick: (String) -> Unit,
    onDeleteClick: (TransactionListItemDto) -> Unit,
    onCreateClick: () -> Unit
) {
    var accountMenuExpanded by remember { mutableStateOf(false) }
    val selectedAccountName = state.accounts.firstOrNull { it.id == state.selectedAccountId }?.name
        ?: "Todas las cuentas"
    val groupedByDate = remember(state.transactions) {
        state.transactions.groupBy { it.date }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        // iOS Navigation Bar: Account Menu Picker on left, Filter + Add ("+") on right
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(FinancePyColors.buttonBgPrimary().copy(alpha = 0.12f))
                        .clickable { accountMenuExpanded = true }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = selectedAccountName,
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.buttonBgPrimary(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Spacer(modifier = Modifier.width(2.dp))
                    Icon(
                        imageVector = Icons.Default.ArrowDropDown,
                        contentDescription = null,
                        tint = FinancePyColors.buttonBgPrimary(),
                        modifier = Modifier.size(18.dp)
                    )
                }

                DropdownMenu(
                    expanded = accountMenuExpanded,
                    onDismissRequest = { accountMenuExpanded = false }
                ) {
                    val allSelected = state.selectedAccountId == null
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = "Todas las cuentas",
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = if (allSelected) FontWeight.SemiBold else FontWeight.Normal
                                ),
                                color = if (allSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.textPrimary()
                            )
                        },
                        trailingIcon = if (allSelected) {
                            {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = null,
                                    tint = FinancePyColors.buttonBgPrimary(),
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        } else null,
                        onClick = {
                            accountMenuExpanded = false
                            onSelectAccount(null)
                        }
                    )
                    state.accounts.forEach { acc ->
                        val isSelected = acc.id == state.selectedAccountId
                        DropdownMenuItem(
                            text = {
                                Text(
                                    text = acc.name,
                                    style = MaterialTheme.typography.bodyMedium.copy(
                                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                                    ),
                                    color = if (isSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.textPrimary()
                                )
                            },
                            trailingIcon = if (isSelected) {
                                {
                                    Icon(
                                        imageVector = Icons.Default.Check,
                                        contentDescription = null,
                                        tint = FinancePyColors.buttonBgPrimary(),
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            } else null,
                            onClick = {
                                accountMenuExpanded = false
                                onSelectAccount(acc.id)
                            }
                        )
                    }
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(
                    onClick = onOpenFilters,
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Tune,
                        contentDescription = "Filtrar",
                        tint = FinancePyColors.buttonBgPrimary(),
                        modifier = Modifier.size(20.dp)
                    )
                }
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .clip(CircleShape)
                        .background(FinancePyColors.buttonBgPrimary())
                        .clickable(onClick = onCreateClick),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "Nueva transacción",
                        tint = FinancePyColors.White,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }

        // iOS Large Title + Search Bar + Segmented Control
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = "Transacciones",
                style = MaterialTheme.typography.headlineLarge,
                color = FinancePyColors.textPrimary()
            )

            AppSearchField(
                value = state.searchQuery,
                onValueChange = onSearchQueryChange,
                placeholder = "Buscar",
                modifier = Modifier.fillMaxWidth()
            )

            AppSegmentedControl(
                options = listOf(
                    "all" to "Todas",
                    "income" to "Ingresos",
                    "expense" to "Gastos"
                ),
                selected = state.selectedType,
                onSelect = onSelectType,
                modifier = Modifier.fillMaxWidth()
            )
        }

        if (state.isOffline) {
            Text(
                text = "Sin conexión · mostrando últimos 90 días guardados",
                style = MaterialTheme.typography.labelMedium,
                color = FinancePyColors.textSecondary(),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp)
            )
        } else {
            Spacer(modifier = Modifier.height(8.dp))
        }

        when {
            state.isLoading && state.transactions.isEmpty() -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = FinancePyColors.buttonBgPrimary())
                }
            }
            state.transactions.isEmpty() -> {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = "No hay transacciones guardadas.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
            else -> {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = 16.dp,
                        top = 8.dp,
                        end = 16.dp,
                        bottom = AppBottomNavOverlayClearance + 16.dp
                    ),
                    verticalArrangement = Arrangement.spacedBy(18.dp)
                ) {
                    groupedByDate.forEach { (date, entriesForDate) ->
                        item(key = "section_$date") {
                            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(
                                    text = date.uppercase(),
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                                    color = FinancePyColors.textSecondary(),
                                    modifier = Modifier.padding(horizontal = 4.dp)
                                )
                                AppGroupedListCard {
                                    entriesForDate.forEachIndexed { idx, entry ->
                                        IosTransactionRow(
                                            entry = entry,
                                            onClick = { if (!entry.pending) onTransactionClick(entry.id) },
                                            onEditClick = { if (!entry.pending) onTransactionClick(entry.id) },
                                            onDeleteClick = { onDeleteClick(entry) }
                                        )
                                        if (idx < entriesForDate.lastIndex) {
                                            HorizontalDivider(
                                                modifier = Modifier.padding(start = 60.dp),
                                                thickness = 0.5.dp,
                                                color = FinancePyColors.borderSecondary()
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (state.isLoadingMore) {
                        item {
                            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(22.dp),
                                    color = FinancePyColors.buttonBgPrimary()
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
private fun IosTransactionRow(
    entry: TransactionListItemDto,
    onClick: () -> Unit,
    onEditClick: () -> Unit,
    onDeleteClick: () -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }
    val dotColor = entry.category?.color?.let { parseHexColor(it) } ?: FinancePyColors.buttonBgPrimary()
    val isIncome = entry.classification == "income"

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(start = 14.dp, end = 8.dp, top = 11.dp, bottom = 11.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(34.dp)
                    .clip(CircleShape)
                    .background(dotColor.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(dotColor)
                )
            }
            Spacer(modifier = Modifier.width(12.dp))

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                Text(
                    text = entry.name,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Row(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    entry.category?.name?.takeIf { it.isNotBlank() }?.let { catName ->
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(4.dp))
                                .background(dotColor.copy(alpha = 0.15f))
                                .padding(horizontal = 6.dp, vertical = 2.dp)
                        ) {
                            Text(
                                text = catName,
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                                color = dotColor,
                                maxLines = 1
                            )
                        }
                    }

                    val secondaryInfo = buildString {
                        if (entry.account.name.isNotBlank()) {
                            append(entry.account.name)
                        } else {
                            append(entry.date)
                        }
                        if (entry.pending) {
                            append(" · Pendiente")
                        }
                    }
                    Text(
                        text = secondaryInfo,
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        Text(
            text = formatMoney(entry.amount_cents, entry.currency),
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
            color = if (isIncome) FinancePyColors.success() else FinancePyColors.textPrimary()
        )

        Box {
            IconButton(
                onClick = { showMenu = true },
                modifier = Modifier.size(32.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.MoreHoriz,
                    contentDescription = "Más opciones",
                    tint = FinancePyColors.textSubdued(),
                    modifier = Modifier.size(18.dp)
                )
            }
            DropdownMenu(
                expanded = showMenu,
                onDismissRequest = { showMenu = false }
            ) {
                if (!entry.pending) DropdownMenuItem(
                    text = { Text("Editar") },
                    onClick = {
                        showMenu = false
                        onEditClick()
                    }
                )
                DropdownMenuItem(
                    text = {
                        Text(
                            text = if (entry.pending) "Descartar" else "Eliminar",
                            color = FinancePyColors.destructive()
                        )
                    },
                    onClick = {
                        showMenu = false
                        onDeleteClick()
                    }
                )
            }
        }
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
                        text = if (entry.pending) "${entry.date} · Pendiente de sincronizar" else entry.date,
                        style = MaterialTheme.typography.labelMedium,
                        color = if (entry.pending) FinancePyColors.textSecondary() else FinancePyColors.textSubdued()
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
                    if (!entry.pending) DropdownMenuItem(
                        text = { Text("Editar") },
                        onClick = {
                            showMenu = false
                            onEditClick()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text(if (entry.pending) "Descartar" else "Eliminar") },
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
