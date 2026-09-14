package py.com.cdco.financespy.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.Handshake
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.PieChart
import androidx.compose.material.icons.filled.ReceiptLong
import androidx.compose.material.icons.filled.Rule
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.ui.graphics.vector.ImageVector

// Ítem navegable único, identificado por un id estable (persistido en preferencias
// locales) en vez de la ruta cruda -- la ruta de detalle/form cambia según
// parámetros, pero el id de nav siempre apunta al mismo destino de lista.
data class NavItem(
    val id: String,
    val label: String,
    val route: String,
    val icon: ImageVector
)

object NavItems {
    val DASHBOARD = NavItem("dashboard", "Dashboard", Routes.DASHBOARD, Icons.Filled.PieChart)
    val TRANSACTIONS = NavItem("transactions", "Transacciones", Routes.TRANSACTIONS, Icons.Filled.CreditCard)
    val REPORTS = NavItem("reports", "Reportes", Routes.REPORTS, Icons.Filled.BarChart)
    val BUDGETS = NavItem("budgets", "Presupuestos", Routes.BUDGETS, Icons.Filled.Map)
    val GOALS = NavItem("goals", "Metas", Routes.GOALS, Icons.Filled.TrackChanges)
    val RECEIVABLES = NavItem("receivables", "Cuentas a Cobrar", Routes.RECEIVABLES, Icons.Filled.Handshake)
    val RULES = NavItem("rules", "Reglas", Routes.RULES, Icons.Filled.Rule)
    val PRODUCTS = NavItem("products", "Productos", Routes.PRODUCTS, Icons.Filled.Inventory2)
    val SALES = NavItem("sales", "Ventas", Routes.SALES, Icons.Filled.ReceiptLong)
    val PURCHASE_ORDERS = NavItem("purchase_orders", "Compras", Routes.PURCHASE_ORDERS, Icons.Filled.LocalShipping)
    val FLEET = NavItem("fleet", "Flota", Routes.FLEET, Icons.Filled.DirectionsCar)

    // Mismos 6 ítems y mismo orden que la barra inferior mobile de la web
    // (app/views/layouts/application.html.erb, mobile_nav_items) -- default de
    // fábrica para que el primer arranque ya se vea igual a la web sin configurar nada.
    val CORE_DEFAULT_ORDER = listOf(DASHBOARD, TRANSACTIONS, REPORTS, BUDGETS, GOALS, RECEIVABLES).map { it.id }

    // Todos los ítems core (sin depender de business_mode) + los de modo negocio,
    // que solo se ofrecen como opción si la family los tiene habilitados.
    val CORE = listOf(DASHBOARD, TRANSACTIONS, REPORTS, BUDGETS, GOALS, RECEIVABLES, RULES)
    val BUSINESS = listOf(PRODUCTS, SALES, PURCHASE_ORDERS, FLEET)

    fun byId(id: String): NavItem? = (CORE + BUSINESS).find { it.id == id }

    fun pool(businessModeEnabled: Boolean): List<NavItem> =
        if (businessModeEnabled) CORE + BUSINESS else CORE
}
