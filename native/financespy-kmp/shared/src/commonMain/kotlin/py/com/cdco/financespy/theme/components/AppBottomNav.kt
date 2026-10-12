package py.com.cdco.financespy.theme.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.theme.FinancePyColors

// AppBottomNav now floats as an overlay on top of screen content (see App.kt)
// instead of reserving space via Scaffold's bottomBar slot, so screens' own
// FloatingActionButtons -- previously sitting safely above the old solid,
// space-reserving bar -- need this much extra bottom padding to clear the
// pill's visible content + its own vertical margin, or they render directly
// underneath it: visually hidden and untappable (the pill's rectangular
// layout bounds intercept touches there even where its clipped shape looks
// transparent). Scaffold already applies system nav-bar insets to FABs on
// its own, so this is on top of that, not instead of it.
val AppBottomNavOverlayClearance = 96.dp

// Replica el diseño real de la barra inferior de la web (mobile, `_nav_item.html.erb`):
// ícono en box redondeado 32dp, activo = fondo container + texto/ícono primario,
// inactivo = sin fondo + texto/ícono secundario. Label 11sp debajo.
//
// Flota separada de los 3 bordes (como el dock/tab bar de iOS 26 Liquid Glass)
// en vez de ser una barra sólida pegada de punta a punta -- navigationBarsPadding
// primero para despejar los botones de navegación del sistema, el margen de
// 16dp/12dp después para que quede despegada de los bordes de la pantalla.
@Composable
fun AppBottomNav(
    items: List<NavItem>,
    currentRoute: String?,
    onNavigate: (NavItem) -> Unit,
    onMoreClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    // Plays the glass's materialize-in once on first composition, instead of
    // the bar just popping in fully formed -- matches the Apple reference's
    // "surface forming" feel described in GlassEffectTransition.materialize.
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    AnimatedVisibility(
        visible = visible,
        enter = GlassTransitions.materializeEnter,
        exit = GlassTransitions.materializeExit,
        modifier = modifier
    ) {
        val shape = RoundedCornerShape(28.dp)
        Column(
            modifier = Modifier
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .fillMaxWidth()
                .liquidGlass(shape, contrastBoost = 0.18f)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp),
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                items.forEach { item ->
                    val active = currentRoute == item.route
                    AppBottomNavItem(
                        item = item,
                        active = active,
                        onClick = { onNavigate(item) },
                        modifier = Modifier.weight(1f)
                    )
                }
                if (onMoreClick != null) {
                    AppBottomNavMoreItem(
                        onClick = onMoreClick,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun AppBottomNavMoreItem(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.selectable(selected = false, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Filled.Menu,
                contentDescription = "Más opciones",
                tint = FinancePyColors.textSecondary(),
                modifier = Modifier.size(18.dp)
            )
        }
        Text(
            text = "Más",
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
            color = FinancePyColors.textSecondary(),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

@Composable
private fun AppBottomNavItemIcon(
    item: NavItem,
    active: Boolean
) {
    // Solid filled circular badge behind the active icon instead of the old
    // rounded-square container-color fill -- matches the native iOS Liquid
    // Glass tab bar's active-tab badge (a solid circle, not a translucent
    // square). Kept on-brand: the badge uses buttonBgPrimary (black/white),
    // not iOS's default blue tint, since FinancePY's own palette has no blue.
    val badgeColor = FinancePyColors.buttonBgPrimary()
    val iconColorOnBadge = FinancePyColors.surface()
    val inactiveColor = FinancePyColors.textSecondary()

    Box(
        modifier = Modifier.size(32.dp),
        contentAlignment = Alignment.Center
    ) {
        AnimatedVisibility(
            visible = active,
            enter = GlassTransitions.materializeEnter,
            exit = GlassTransitions.materializeExit
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(badgeColor)
            )
        }
        Icon(
            imageVector = item.icon,
            contentDescription = item.label,
            tint = if (active) iconColorOnBadge else inactiveColor,
            modifier = Modifier.size(18.dp)
        )
    }
}

@Composable
private fun AppBottomNavItem(
    item: NavItem,
    active: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val contentColor = if (active) FinancePyColors.textPrimary() else FinancePyColors.textSecondary()

    Column(
        modifier = modifier.selectable(selected = active, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        AppBottomNavItemIcon(item = item, active = active)
        Text(
            text = item.label,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 11.sp),
            color = contentColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}
