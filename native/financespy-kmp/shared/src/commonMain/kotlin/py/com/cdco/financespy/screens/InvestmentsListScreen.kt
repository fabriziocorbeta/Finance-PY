package py.com.cdco.financespy.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.MarketPointDto
import py.com.cdco.financespy.api.dto.MarketQuoteDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney
import py.com.cdco.financespy.utils.formatPercent
import kotlin.math.roundToLong

private val MARKET_RANGES = listOf(
    "5d" to "5D",
    "1mo" to "1M",
    "3mo" to "3M",
    "6mo" to "6M",
    "ytd" to "YTD",
    "1y" to "1A",
    "5y" to "5A"
)

private val QUICK_WATCH_PICKS = listOf("SPY", "QQQ", "VOO", "VT", "GLD", "AAPL", "MSFT", "NVDA")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvestmentsListScreen(
    viewModel: InvestmentsListViewModel,
    onAccountClick: (String) -> Unit,
    onHoldingClick: (String) -> Unit,
    onViewPerformanceClick: () -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    var tickerInput by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Inversiones y Mercados", style = MaterialTheme.typography.titleLarge) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver")
                    }
                },
                actions = {
                    IconButton(onClick = { viewModel.refresh(forceMarketRefresh = true) }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Actualizar precios")
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
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (state.isLoading && state.investmentAccounts.isEmpty() && state.indexQuotes.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item { Spacer(modifier = Modifier.height(4.dp)) }

                    // 1. Market Indices Strip
                    if (state.indexQuotes.isNotEmpty()) {
                        item {
                            Text(
                                text = "Índices de mercado",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = FinancePyColors.textPrimary()
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                items(state.indexQuotes, key = { it.ticker }) { idx ->
                                    IndexQuoteCard(
                                        quote = idx,
                                        selected = idx.ticker.equals(state.selectedTicker, ignoreCase = true),
                                        onClick = { viewModel.selectQuote(idx.ticker) }
                                    )
                                }
                            }
                        }
                    }

                    // 2. Interactive Quote & Chart Card
                    item {
                        FeaturedQuoteChartCard(
                            quote = state.featuredQuote,
                            selectedRange = state.selectedRange,
                            isLoading = state.isLoadingMarket,
                            onSelectRange = { range ->
                                viewModel.selectQuote(state.selectedTicker, range)
                            },
                            onAddToWatchlist = { ticker ->
                                viewModel.addToWatchlist(ticker)
                            }
                        )
                    }

                    // 3. Portfolio Summary & Holdings
                    item {
                        Text(
                            text = "Mis Inversiones",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                    }

                    if (state.investmentAccounts.isNotEmpty()) {
                        item {
                            PortfolioSummaryHeaderCard(
                                totalValueCents = state.totalPortfolioValueCents,
                                currency = state.currency,
                                accountsCount = state.investmentAccounts.size,
                                onViewPerformanceClick = onViewPerformanceClick
                            )
                        }

                        items(state.investmentAccounts, key = { it.id }) { account ->
                            InvestmentAccountRow(account = account, onClick = { onAccountClick(account.id) })
                        }

                        if (state.holdingsBySecurity.isNotEmpty()) {
                            item {
                                AppCard(modifier = Modifier.fillMaxWidth()) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Text(
                                            text = "ETFs y Acciones en Portafolio",
                                            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold),
                                            color = FinancePyColors.textSecondary()
                                        )
                                        Spacer(modifier = Modifier.height(10.dp))
                                        state.holdingsBySecurity.forEachIndexed { idx, holding ->
                                            if (idx > 0) {
                                                HorizontalDivider(
                                                    modifier = Modifier.padding(vertical = 10.dp),
                                                    color = FinancePyColors.textSecondary().copy(alpha = 0.12f)
                                                )
                                            }
                                            HoldingSecurityRow(
                                                holding = holding,
                                                quote = state.holdingQuotesBySecurity[holding.securityId],
                                                totalValueCents = state.totalPortfolioValueCents,
                                                onClick = { viewModel.selectQuote(holding.ticker) },
                                                onDetailClick = { onHoldingClick(holding.securityId) }
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        item {
                            AppCard(modifier = Modifier.fillMaxWidth()) {
                                Text(
                                    text = "No tenés cuentas de inversión registradas todavía. Puedes seguir ETFs, acciones e índices abajo.",
                                    modifier = Modifier.padding(16.dp),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                        }
                    }

                    // 4. Watchlist Section
                    item {
                        WatchlistSectionCard(
                            watchlistQuotes = state.watchlistQuotes,
                            tickerInput = tickerInput,
                            isMutating = state.isMutatingWatchlist,
                            marketError = state.marketError,
                            onTickerInputChange = { tickerInput = it },
                            onAddTicker = { ticker ->
                                viewModel.addToWatchlist(ticker)
                                tickerInput = ""
                            },
                            onSelectQuote = { ticker -> viewModel.selectQuote(ticker) },
                            onRemoveQuote = { id -> viewModel.removeFromWatchlist(id) }
                        )
                    }

                    item { Spacer(modifier = Modifier.height(24.dp)) }
                }
            }
        }
    }
}

@Composable
private fun IndexQuoteCard(
    quote: MarketQuoteDto,
    selected: Boolean,
    onClick: () -> Unit
) {
    val positive = (quote.change_percent ?: 0.0) >= 0.0
    val trendColor = if (positive) Color(0xFF16A34A) else Color(0xFFE11D48)

    Surface(
        modifier = Modifier.width(168.dp).clickable(onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        color = FinancePyColors.container(),
        border = if (selected) BorderStroke(1.5.dp, FinancePyColors.textPrimary()) else BorderStroke(1.dp, FinancePyColors.textSecondary().copy(alpha = 0.15f))
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = quote.name,
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                quote.change_percent?.let { pct ->
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = trendColor.copy(alpha = 0.12f)
                    ) {
                        Text(
                            text = "${if (pct >= 0) "+" else ""}${formatPercent(pct)}",
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                            color = trendColor,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                        )
                    }
                }
            }
            Text(
                text = quote.ticker,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom
            ) {
                Text(
                    text = quote.current_price?.let { formatQuoteNumber(it) } ?: "—",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                if (quote.points.size >= 2) {
                    MarketSparkline(
                        points = quote.points,
                        color = trendColor,
                        modifier = Modifier.width(52.dp).height(24.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun FeaturedQuoteChartCard(
    quote: MarketQuoteDto?,
    selectedRange: String,
    isLoading: Boolean,
    onSelectRange: (String) -> Unit,
    onAddToWatchlist: (String) -> Unit
) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (quote == null) {
                Box(modifier = Modifier.fillMaxWidth().height(160.dp), contentAlignment = Alignment.Center) {
                    if (isLoading) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    } else {
                        Text("Selecciona un índice o activo para ver el gráfico", color = FinancePyColors.textSecondary())
                    }
                }
            } else {
                val positive = (quote.change_percent ?: 0.0) >= 0.0
                val dayColor = if (positive) Color(0xFF16A34A) else Color(0xFFE11D48)
                val periodPositive = (quote.period_change_percent ?: 0.0) >= 0.0
                val periodColor = if (periodPositive) Color(0xFF16A34A) else Color(0xFFE11D48)

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(
                                text = quote.name,
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = FinancePyColors.textPrimary(),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Surface(
                                shape = RoundedCornerShape(6.dp),
                                color = FinancePyColors.surface()
                            ) {
                                Text(
                                    text = categoryLabel(quote.category),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = FinancePyColors.textSecondary(),
                                    modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                                )
                            }
                        }
                        Text(
                            text = listOfNotNull(quote.ticker, quote.exchange_name).joinToString(" · "),
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                    }

                    if (quote.watchlist_item_id == null) {
                        AppButton(
                            text = "+ Seguir",
                            onClick = { onAddToWatchlist(quote.ticker) },
                            variant = ButtonVariant.Secondary
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = quote.current_price?.let { "${formatQuoteNumber(it)} ${quote.currency}" } ?: "—",
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )
                    if (isLoading) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    quote.change_percent?.let { pct ->
                        Text(
                            text = "Hoy: ${if (pct >= 0) "+" else ""}${formatPercent(pct)}",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = dayColor
                        )
                    }
                    quote.period_change_percent?.let { pct ->
                        Text(
                            text = "${selectedRange.uppercase()}: ${if (pct >= 0) "+" else ""}${formatPercent(pct)}",
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                            color = periodColor
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    MARKET_RANGES.forEach { (key, label) ->
                        FilterChip(
                            selected = selectedRange == key,
                            onClick = { onSelectRange(key) },
                            label = { Text(label) }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(10.dp))

                if (quote.points.size >= 2) {
                    MarketAreaChart(
                        points = quote.points,
                        color = periodColor,
                        modifier = Modifier.fillMaxWidth().height(150.dp)
                    )
                } else {
                    Box(
                        modifier = Modifier.fillMaxWidth().height(110.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Sin datos históricos disponibles para este rango",
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    StatCell("Cierre ant.", quote.previous_close?.let { formatQuoteNumber(it) } ?: "—", Modifier.weight(1f))
                    StatCell(
                        "Rango día",
                        if (quote.day_low != null && quote.day_high != null) "${formatQuoteNumber(quote.day_low)} - ${formatQuoteNumber(quote.day_high)}" else "—",
                        Modifier.weight(1f)
                    )
                    StatCell(
                        "52 sem.",
                        if (quote.fifty_two_week_low != null && quote.fifty_two_week_high != null) "${formatQuoteNumber(quote.fifty_two_week_low)} - ${formatQuoteNumber(quote.fifty_two_week_high)}" else "—",
                        Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun StatCell(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier.padding(end = 6.dp)) {
        Text(text = label, style = MaterialTheme.typography.labelSmall, color = FinancePyColors.textSecondary())
        Text(
            text = value,
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
            color = FinancePyColors.textPrimary(),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun WatchlistSectionCard(
    watchlistQuotes: List<MarketQuoteDto>,
    tickerInput: String,
    isMutating: Boolean,
    marketError: String?,
    onTickerInputChange: (String) -> Unit,
    onAddTicker: (String) -> Unit,
    onSelectQuote: (String) -> Unit,
    onRemoveQuote: (String) -> Unit
) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Column {
                Text(
                    text = "Lista de Seguimiento",
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                Text(
                    text = "ETFs, acciones e índices seguidos en tiempo real",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                OutlinedTextField(
                    value = tickerInput,
                    onValueChange = onTickerInputChange,
                    placeholder = { Text("Ticker (ej. VOO, ^GSPC)") },
                    singleLine = true,
                    modifier = Modifier.weight(1f)
                )
                IconButton(
                    onClick = { onAddTicker(tickerInput) },
                    enabled = !isMutating && tickerInput.isNotBlank(),
                    modifier = Modifier
                        .background(FinancePyColors.textPrimary(), RoundedCornerShape(10.dp))
                        .size(48.dp)
                ) {
                    if (isMutating) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), color = FinancePyColors.container(), strokeWidth = 2.dp)
                    } else {
                        Icon(Icons.Default.Add, contentDescription = "Seguir", tint = FinancePyColors.container())
                    }
                }
            }

            val existing = watchlistQuotes.map { it.ticker.uppercase() }.toSet()
            val availablePicks = QUICK_WATCH_PICKS.filterNot { it in existing }
            if (availablePicks.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    availablePicks.forEach { pick ->
                        Surface(
                            modifier = Modifier.clickable(enabled = !isMutating) { onAddTicker(pick) },
                            shape = RoundedCornerShape(16.dp),
                            color = FinancePyColors.surface()
                        ) {
                            Text(
                                text = "+ $pick",
                                style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Medium),
                                color = FinancePyColors.textPrimary(),
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp)
                            )
                        }
                    }
                }
            }

            marketError?.let { err ->
                Text(text = err, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
            }

            if (watchlistQuotes.isEmpty()) {
                Text(
                    text = "Tu lista de seguimiento está vacía. Agrega un ticker arriba (ej. SPY, QQQ, VOO, AAPL).",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
                )
            } else {
                watchlistQuotes.forEachIndexed { idx, quote ->
                    if (idx > 0) {
                        HorizontalDivider(color = FinancePyColors.textSecondary().copy(alpha = 0.12f))
                    }
                    WatchlistQuoteRow(
                        quote = quote,
                        onClick = { onSelectQuote(quote.ticker) },
                        onRemove = { quote.watchlist_item_id?.let(onRemoveQuote) }
                    )
                }
            }
        }
    }
}

@Composable
private fun WatchlistQuoteRow(
    quote: MarketQuoteDto,
    onClick: () -> Unit,
    onRemove: () -> Unit
) {
    val positive = (quote.change_percent ?: 0.0) >= 0.0
    val dayColor = if (positive) Color(0xFF16A34A) else Color(0xFFE11D48)

    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = quote.ticker,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                Surface(shape = RoundedCornerShape(4.dp), color = FinancePyColors.surface()) {
                    Text(
                        text = categoryLabel(quote.category),
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary(),
                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.dp)
                    )
                }
            }
            Text(
                text = quote.name,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        if (quote.points.size >= 2) {
            MarketSparkline(
                points = quote.points,
                color = dayColor,
                modifier = Modifier.width(48.dp).height(24.dp).padding(horizontal = 4.dp)
            )
        }

        Column(horizontalAlignment = Alignment.End, modifier = Modifier.padding(horizontal = 6.dp)) {
            Text(
                text = quote.current_price?.let { formatQuoteNumber(it) } ?: "—",
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            quote.change_percent?.let { pct ->
                Text(
                    text = "${if (pct >= 0) "+" else ""}${formatPercent(pct)}",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                    color = dayColor
                )
            }
        }

        if (quote.watchlist_item_id != null) {
            IconButton(onClick = onRemove, modifier = Modifier.size(32.dp)) {
                Icon(
                    Icons.Default.Delete,
                    contentDescription = "Eliminar",
                    tint = FinancePyColors.textSecondary(),
                    modifier = Modifier.size(18.dp)
                )
            }
        }
    }
}

@Composable
private fun MarketSparkline(points: List<MarketPointDto>, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        if (points.size < 2) return@Canvas
        val minVal = points.minOf { it.value }
        val maxVal = points.maxOf { it.value }
        val range = (maxVal - minVal).takeIf { it > 0.0 } ?: 1.0
        val stepX = size.width / (points.size - 1).coerceAtLeast(1)

        val path = Path()
        points.forEachIndexed { index, pt ->
            val x = index * stepX
            val y = size.height - (((pt.value - minVal) / range).toFloat() * size.height)
            if (index == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(
            path = path,
            color = color,
            style = Stroke(width = 3f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        )
    }
}

@Composable
private fun MarketAreaChart(points: List<MarketPointDto>, color: Color, modifier: Modifier = Modifier) {
    Canvas(modifier = modifier) {
        if (points.size < 2) return@Canvas
        val minVal = points.minOf { it.value }
        val maxVal = points.maxOf { it.value }
        val range = (maxVal - minVal).takeIf { it > 0.0 } ?: 1.0
        val stepX = size.width / (points.size - 1).coerceAtLeast(1)
        val topPad = 8f
        val drawHeight = (size.height - topPad * 2).coerceAtLeast(1f)

        val linePath = Path()
        val fillPath = Path()
        points.forEachIndexed { index, pt ->
            val x = index * stepX
            val y = topPad + drawHeight - (((pt.value - minVal) / range).toFloat() * drawHeight)
            if (index == 0) {
                linePath.moveTo(x, y)
                fillPath.moveTo(x, size.height)
                fillPath.lineTo(x, y)
            } else {
                linePath.lineTo(x, y)
                fillPath.lineTo(x, y)
            }
            if (index == points.lastIndex) {
                fillPath.lineTo(x, size.height)
                fillPath.close()
            }
        }

        drawPath(
            path = fillPath,
            brush = Brush.verticalGradient(
                colors = listOf(color.copy(alpha = 0.24f), Color.Transparent),
                startY = 0f,
                endY = size.height
            )
        )
        drawPath(
            path = linePath,
            color = color,
            style = Stroke(width = 4.5f, cap = StrokeCap.Round, join = StrokeJoin.Round)
        )

        val lastY = topPad + drawHeight - (((points.last().value - minVal) / range).toFloat() * drawHeight)
        drawCircle(color = color, radius = 7f, center = Offset(size.width, lastY))
    }
}

private fun categoryLabel(category: String): String = when (category.lowercase()) {
    "index" -> "Índice"
    "etf" -> "ETF"
    "crypto" -> "Cripto"
    "fund" -> "Fondo"
    else -> "Acción"
}

private fun formatQuoteNumber(value: Double): String {
    val rounded = (value * 100.0).roundToLong()
    val whole = rounded / 100
    val frac = kotlin.math.abs(rounded % 100)
    return "$whole.${frac.toString().padStart(2, '0')}"
}

@Composable
private fun PortfolioSummaryHeaderCard(
    totalValueCents: Long,
    currency: String,
    accountsCount: Int,
    onViewPerformanceClick: () -> Unit
) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Valor total del portafolio",
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary()
            )
            Text(
                text = formatMoney(totalValueCents, currency),
                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$accountsCount cuenta${if (accountsCount == 1) "" else "s"} de inversión",
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
            Spacer(modifier = Modifier.height(12.dp))
            AppButton(
                text = "Ver rendimiento",
                onClick = onViewPerformanceClick,
                variant = ButtonVariant.Secondary,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun InvestmentAccountRow(account: AccountDto, onClick: () -> Unit) {
    AppCard(modifier = Modifier.fillMaxWidth().clickable { onClick() }) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = account.name,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.textPrimary()
                )
                account.institution_name?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
            Text(
                text = formatMoney(account.balance_cents, account.currency),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }
    }
}

@Composable
private fun HoldingSecurityRow(
    holding: AggregatedHolding,
    quote: MarketQuoteDto?,
    totalValueCents: Long,
    onClick: () -> Unit,
    onDetailClick: () -> Unit
) {
    val weightPct = if (totalValueCents > 0) (holding.amountCents * 100.0 / totalValueCents) else 0.0
    val dayColor = if ((quote?.change_percent ?: 0.0) >= 0.0) Color(0xFF16A34A) else Color(0xFFE11D48)

    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = holding.ticker,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                quote?.change_percent?.let { pct ->
                    Text(
                        text = "${if (pct >= 0) "+" else ""}${formatPercent(pct)}",
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = dayColor
                    )
                }
            }
            Text(
                text = holding.name,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary(),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        if (quote != null && quote.points.size >= 2) {
            MarketSparkline(
                points = quote.points,
                color = dayColor,
                modifier = Modifier.width(44.dp).height(22.dp).padding(horizontal = 4.dp)
            )
        }

        Column(
            horizontalAlignment = Alignment.End,
            modifier = Modifier.clickable(onClick = onDetailClick)
        ) {
            Text(
                text = formatMoney(holding.amountCents, holding.currency),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = "${formatPercent(weightPct)} del portafolio",
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
        }
    }
}
