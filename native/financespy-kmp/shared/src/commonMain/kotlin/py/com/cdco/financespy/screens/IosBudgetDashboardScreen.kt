package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import py.com.cdco.financespy.screens.components.BudgetCategoryDetailSheet
import py.com.cdco.financespy.screens.components.parseHexColor
import py.com.cdco.financespy.sync.endOfMonthDate
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppBottomNavOverlayClearance
import py.com.cdco.financespy.theme.components.AppGroupedListCard
import py.com.cdco.financespy.theme.components.AppSegmentedControl
import py.com.cdco.financespy.utils.formatMoney

private val MONTH_NAMES_ES = listOf(
    "enero", "febrero", "marzo", "abril", "mayo", "junio",
    "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"
)

@Composable
fun IosBudgetDashboardScreen(
    viewModel: BudgetDashboardViewModel,
    onNavigateToEditor: (budgetId: String) -> Unit = {},
    onNavigateToCategoryTransactions: (categoryId: String, startDate: String, endDate: String) -> Unit = { _, _, _ -> },
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()
    var selectedSummaryTab by remember { mutableStateOf("general") }

    val monthName = if (uiState.month in 1..12) MONTH_NAMES_ES[uiState.month - 1] else "mes ${uiState.month}"
    val monthTitle = if (uiState.budgetName.isNotBlank()) uiState.budgetName else "$monthName ${uiState.year}"

    Surface(
        modifier = modifier.fillMaxSize(),
        color = FinancePyColors.surface()
    ) {
        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = FinancePyColors.buttonBgPrimary())
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    top = 8.dp,
                    end = 16.dp,
                    bottom = AppBottomNavOverlayClearance + 24.dp
                ),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // 1. Centered Navigation Header: Screen Title + Month Picker
                item {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "Presupuesto",
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 17.sp
                            ),
                            color = FinancePyColors.textPrimary(),
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(6.dp))
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            IconButton(
                                onClick = { viewModel.selectPreviousMonth() },
                                modifier = Modifier.size(36.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowLeft,
                                    contentDescription = "Mes anterior",
                                    tint = FinancePyColors.buttonBgPrimary(),
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                            Text(
                                text = monthTitle,
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 17.sp
                                ),
                                color = FinancePyColors.textPrimary(),
                                textAlign = TextAlign.Center
                            )
                            IconButton(
                                onClick = { viewModel.selectNextMonth() },
                                modifier = Modifier.size(36.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                    contentDescription = "Mes siguiente",
                                    tint = FinancePyColors.buttonBgPrimary(),
                                    modifier = Modifier.size(24.dp)
                                )
                            }
                        }
                    }
                }

                // 2. Block: "Disponible para asignar"
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Disponible para asignar",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = formatMoney(uiState.availableToAllocate, uiState.currency),
                                style = MaterialTheme.typography.headlineMedium.copy(
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 26.sp
                                ),
                                color = FinancePyColors.textPrimary()
                            )
                        }
                        if (uiState.initialized && uiState.budgetId != null) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(FinancePyColors.buttonBgPrimary().copy(alpha = 0.12f))
                                    .clickable { onNavigateToEditor(uiState.budgetId!!) }
                                    .padding(horizontal = 16.dp, vertical = 7.dp)
                            ) {
                                Text(
                                    text = "Asignar",
                                    style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.SemiBold),
                                    color = FinancePyColors.buttonBgPrimary()
                                )
                            }
                        }
                    }
                }

                // 3. Card: "Resumen de Gastos"
                item {
                    AppGroupedListCard {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "Resumen de Gastos",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Normal),
                                color = FinancePyColors.textSecondary()
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(
                                        text = "Gastado:",
                                        style = MaterialTheme.typography.labelMedium,
                                        color = Color(0xFFFF3B30)
                                    )
                                    Text(
                                        text = formatMoney(uiState.actualSpending, uiState.currency),
                                        style = MaterialTheme.typography.titleLarge.copy(
                                            fontWeight = FontWeight.Bold,
                                            fontSize = 20.sp
                                        ),
                                        color = Color(0xFFFF3B30)
                                    )
                                }
                                Text(
                                    text = "Presupuestado: ${formatMoney(uiState.budgetedSpending, uiState.currency)}",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                        }
                    }
                }

                // 4. Primary Segmented Control: General / Ingresos
                item {
                    AppSegmentedControl(
                        options = listOf(
                            "general" to "General",
                            "income" to "Ingresos"
                        ),
                        selected = selectedSummaryTab,
                        onSelect = { selectedSummaryTab = it },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // 5. Totals Card
                item {
                    AppGroupedListCard {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalArrangement = Arrangement.spacedBy(10.dp)
                        ) {
                            if (selectedSummaryTab == "general") {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Presupuestado",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = FinancePyColors.textPrimary()
                                    )
                                    Text(
                                        text = formatMoney(uiState.budgetedSpending, uiState.currency),
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Gastado",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = FinancePyColors.textPrimary()
                                    )
                                    Text(
                                        text = formatMoney(uiState.actualSpending, uiState.currency),
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                            } else {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Ingreso esperado",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = FinancePyColors.textPrimary()
                                    )
                                    Text(
                                        text = formatMoney(uiState.expectedIncome, uiState.currency),
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Text(
                                        text = "Ingreso real",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = FinancePyColors.textPrimary()
                                    )
                                    Text(
                                        text = formatMoney(uiState.actualIncome, uiState.currency),
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                            }
                        }
                    }
                }

                // 6. Section Header: Categorías (21) + Editar
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 4.dp, vertical = 2.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Categorías (${uiState.categories.size})",
                            style = MaterialTheme.typography.titleMedium.copy(
                                fontWeight = FontWeight.Bold,
                                fontSize = 18.sp
                            ),
                            color = FinancePyColors.textPrimary()
                        )
                        if (uiState.initialized && uiState.budgetId != null) {
                            Box(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(16.dp))
                                    .background(FinancePyColors.buttonBgPrimary().copy(alpha = 0.12f))
                                    .clickable { onNavigateToEditor(uiState.budgetId!!) }
                                    .padding(horizontal = 14.dp, vertical = 6.dp)
                            ) {
                                Text(
                                    text = "Editar",
                                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                                    color = FinancePyColors.buttonBgPrimary()
                                )
                            }
                        }
                    }
                }

                // 7. Secondary Segmented Control: Todas / Sobre presupuesto / En camino
                item {
                    AppSegmentedControl(
                        options = listOf(
                            "all" to "Todas",
                            "over_budget" to "Sobre presupuesto",
                            "on_track" to "En camino"
                        ),
                        selected = uiState.categoryFilterTab,
                        onSelect = { viewModel.setCategoryFilterTab(it) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                // 8. Categories Grouped List Card
                val filteredCategories = uiState.categories.filter { cat ->
                    when (uiState.categoryFilterTab) {
                        "over_budget" -> cat.status == BudgetCategoryStatus.OVER_BUDGET
                        "on_track" -> cat.status == BudgetCategoryStatus.ON_TRACK
                        else -> true
                    }
                }

                if (filteredCategories.isEmpty()) {
                    item {
                        AppGroupedListCard {
                            Text(
                                text = "No hay categorías disponibles para este filtro.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary(),
                                modifier = Modifier.padding(16.dp)
                            )
                        }
                    }
                } else {
                    item {
                        AppGroupedListCard {
                            filteredCategories.forEachIndexed { index, cat ->
                                val dotColor = try {
                                    parseHexColor(cat.color)
                                } catch (e: Exception) {
                                    FinancePyColors.buttonBgPrimary()
                                }
                                val isOver = cat.status == BudgetCategoryStatus.OVER_BUDGET || cat.availableToSpend < 0

                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { viewModel.selectCategory(cat) }
                                        .padding(horizontal = 16.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier
                                            .size(10.dp)
                                            .clip(CircleShape)
                                            .background(dotColor)
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column(modifier = Modifier.weight(1f)) {
                                        Text(
                                            text = cat.name,
                                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                            color = FinancePyColors.textPrimary()
                                        )
                                        Spacer(modifier = Modifier.height(2.dp))
                                        Text(
                                            text = "${uiState.currency} ${cat.actualSpending} / ${uiState.currency} ${cat.budgetedSpending}",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = FinancePyColors.textSecondary()
                                        )
                                    }
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = "${uiState.currency} ${cat.availableToSpend}",
                                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                                        color = if (isOver) Color(0xFFFF3B30) else Color(0xFF34C759)
                                    )
                                }
                                if (index < filteredCategories.lastIndex) {
                                    HorizontalDivider(
                                        modifier = Modifier.padding(start = 38.dp),
                                        thickness = 0.5.dp,
                                        color = FinancePyColors.borderSecondary()
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }

        // Category Detail Bottom Sheet / Modal
        if (uiState.selectedCategory != null) {
            val cat = uiState.selectedCategory!!
            val monthStr = if (uiState.month < 10) "0${uiState.month}" else "${uiState.month}"
            val startDate = "${uiState.year}-$monthStr-01"
            val endDate = endOfMonthDate(uiState.year, uiState.month)

            BudgetCategoryDetailSheet(
                category = cat,
                currency = uiState.currency,
                recentTransactions = uiState.selectedCategoryRecentTransactions,
                isLoadingTransactions = uiState.isLoadingCategoryTransactions,
                onDismiss = { viewModel.selectCategory(null) },
                onViewAllTransactions = {
                    viewModel.selectCategory(null)
                    onNavigateToCategoryTransactions(cat.categoryId, startDate, endDate)
                }
            )
        }
    }
}

