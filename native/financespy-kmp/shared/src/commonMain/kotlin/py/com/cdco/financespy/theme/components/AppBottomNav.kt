package py.com.cdco.financespy.theme.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant

// AppBottomNav now floats as an overlay on top of screen content (see App.kt)
// instead of reserving space via Scaffold's bottomBar slot, so screens' own
// FloatingActionButtons -- previously sitting safely above the old solid,
// space-reserving bar -- need this much extra bottom padding to clear the
// pill's visible content + its own vertical margin, or they render directly
// underneath it: visually hidden and untappable (the pill's rectangular
// layout bounds intercept touches there even where its clipped shape looks
// transparent). Scaffold already applies system nav-bar insets to FABs on
// its own, so this is on top of that, not instead of it.
var AppBottomNavOverlayClearance by mutableStateOf(96.dp)

private val BadgeSize = 32.dp

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
    val variant = LocalUiVariant.current
    val density = LocalDensity.current

    if (variant == UiVariant.IOS) {
        IosTabBar(
            items = items,
            currentRoute = currentRoute,
            onNavigate = onNavigate,
            onMoreClick = onMoreClick,
            modifier = modifier.onGloballyPositioned { coords ->
                val measuredHeight = with(density) { coords.size.height.toDp() }
                if (measuredHeight > 0.dp && measuredHeight != AppBottomNavOverlayClearance) {
                    AppBottomNavOverlayClearance = measuredHeight
                }
            }
        )
        return
    }

    // Plays the glass's materialize-in once on first composition, instead of
    // the bar just popping in fully formed -- matches the Apple reference's
    // "surface forming" feel described in GlassEffectTransition.materialize.
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }

    AnimatedVisibility(
        visible = visible,
        enter = GlassTransitions.materializeEnter,
        exit = GlassTransitions.materializeExit,
        modifier = modifier.onGloballyPositioned { coords ->
            val measuredHeight = with(density) { coords.size.height.toDp() }
            if (measuredHeight > 0.dp && measuredHeight != AppBottomNavOverlayClearance) {
                AppBottomNavOverlayClearance = measuredHeight
            }
        }
    ) {
        val shape = RoundedCornerShape(28.dp)
        Column(
            modifier = Modifier
                .navigationBarsPadding()
                .padding(horizontal = 16.dp, vertical = 12.dp)
                .fillMaxWidth()
                .liquidGlass(shape, contrastBoost = 0.18f)
        ) {
            // Center-x (px, relative to this Box) of each tab item, reported by
            // its own onGloballyPositioned as the Row lays out. Drives the
            // single shared badge below instead of each item owning its own.
            val centers = remember(items) { mutableStateListOf<Float>().apply { repeat(items.size) { add(0f) } } }
            val activeIndex = items.indexOfFirst { it.route == currentRoute }.let { if (it < 0) null else it }

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 6.dp)
            ) {
                if (activeIndex != null && centers.getOrNull(activeIndex)?.let { it > 0f } == true) {
                    LiquidNavBadge(
                        targetCenterPx = centers[activeIndex],
                        color = FinancePyColors.buttonBgPrimary()
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceAround
                ) {
                    items.forEachIndexed { index, item ->
                        val active = currentRoute == item.route
                        AppBottomNavItem(
                            item = item,
                            active = active,
                            onClick = { onNavigate(item) },
                            modifier = Modifier
                                .weight(1f)
                                .onGloballyPositioned { coords ->
                                    val centerX = coords.positionInParent().x + coords.size.width / 2f
                                    if (index < centers.size) centers[index] = centerX
                                }
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
}

// Barra inferior estilo UITabBar (Apple HIG / MainTabView de financespy-ios):
// acoplada de borde a borde en la parte inferior con línea divisoria hairline
// de 0.5dp arriba, fondo translúcido secondarySystemGroupedBackground, íconos
// con tint systemBlue en el tab activo y systemGray en los inactivos, y el
// ítem "Más" con ellipsis horizontal igual que SwiftUI TabView.
@Composable
private fun IosTabBar(
    items: List<NavItem>,
    currentRoute: String?,
    onNavigate: (NavItem) -> Unit,
    onMoreClick: (() -> Unit)?,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(FinancePyColors.container().copy(alpha = 0.96f))
            .navigationBarsPadding()
    ) {
        HorizontalDivider(
            thickness = 0.5.dp,
            color = FinancePyColors.borderSecondary()
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 6.dp, bottom = 4.dp, start = 4.dp, end = 4.dp),
            horizontalArrangement = Arrangement.SpaceAround,
            verticalAlignment = Alignment.CenterVertically
        ) {
            items.forEach { item ->
                val active = currentRoute == item.route
                IosTabBarItem(
                    icon = item.icon,
                    label = item.label,
                    active = active,
                    onClick = { onNavigate(item) },
                    modifier = Modifier.weight(1f)
                )
            }
            if (onMoreClick != null) {
                IosTabBarItem(
                    icon = Icons.Filled.MoreHoriz,
                    label = "Más",
                    active = false,
                    onClick = onMoreClick,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun IosTabBarItem(
    icon: ImageVector,
    label: String,
    active: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val tint = if (active) FinancePyColors.buttonBgPrimary() else FinancePyColors.textSecondary()
    val interactionSource = remember { MutableInteractionSource() }

    Column(
        modifier = modifier
            .selectable(
                selected = active,
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            )
            .padding(vertical = 2.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = tint,
            modifier = Modifier.size(22.dp)
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(
                fontSize = 10.sp,
                fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal
            ),
            color = tint,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

// A single badge that slides and stretches between tab positions instead of
// each tab independently fading its own badge in/out. Modeled on the native
// iOS 26 Liquid Glass tab bar's active-tab indicator (see the reference
// screen recording of the real transition the user provided): the edge
// leading the movement reaches its target quickly while the trailing edge
// follows on a softer spring, so the pill visibly elongates mid-slide --
// "liquid" stretch -- before both edges catch up and it snaps back to a
// circle at rest.
@Composable
private fun BoxScope.LiquidNavBadge(
    targetCenterPx: Float,
    color: Color
) {
    val density = LocalDensity.current
    val badgeSizePx = with(density) { BadgeSize.toPx() }

    val leftAnim = remember { Animatable(targetCenterPx - badgeSizePx / 2f) }
    val rightAnim = remember { Animatable(targetCenterPx + badgeSizePx / 2f) }
    var initialized by remember { mutableStateOf(false) }
    var previousRight by remember { mutableFloatStateOf(targetCenterPx + badgeSizePx / 2f) }

    LaunchedEffect(targetCenterPx) {
        val targetLeft = targetCenterPx - badgeSizePx / 2f
        val targetRight = targetCenterPx + badgeSizePx / 2f

        if (!initialized) {
            leftAnim.snapTo(targetLeft)
            rightAnim.snapTo(targetRight)
            initialized = true
            previousRight = targetRight
            return@LaunchedEffect
        }

        val movingRight = targetRight > previousRight
        previousRight = targetRight

        coroutineScope {
            launch {
                rightAnim.animateTo(
                    targetRight,
                    spring(
                        dampingRatio = if (movingRight) 0.55f else 0.9f,
                        stiffness = if (movingRight) 380f else 260f
                    )
                )
            }
            launch {
                leftAnim.animateTo(
                    targetLeft,
                    spring(
                        dampingRatio = if (movingRight) 0.9f else 0.55f,
                        stiffness = if (movingRight) 260f else 380f
                    )
                )
            }
        }
    }

    val leftDp = with(density) { leftAnim.value.toDp() }
    val widthPx = (rightAnim.value - leftAnim.value).coerceAtLeast(0f)
    val widthDp = with(density) { widthPx.toDp() }

    // TopStart, not CenterStart: the Row's items (icon Box, then label text
    // below) are top-aligned, so the icon sits flush at the top of this same
    // Box -- centering the badge in the Box's full height (icon + label)
    // instead put it lower than the icon, cutting the icon's top edge off
    // the circle.
    Box(
        modifier = Modifier
            .align(Alignment.TopStart)
            .offset(x = leftDp)
            .size(width = widthDp, height = BadgeSize)
            .clip(RoundedCornerShape(percent = 50))
            .background(color)
    )
}

@Composable
private fun AppBottomNavMoreItem(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Touch target stays the full item (selectable on the Column), but the
    // ripple itself is scoped to the 32dp icon circle via a shared
    // interactionSource -- otherwise Compose's default indication fills the
    // whole clickable bounds as an off-center rectangle instead of a ripple
    // centered on what visually looks like the tappable element.
    val interactionSource = remember { MutableInteractionSource() }
    Column(
        modifier = modifier.selectable(
            selected = false,
            interactionSource = interactionSource,
            indication = null,
            onClick = onClick
        ),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(RoundedCornerShape(8.dp))
                .indication(interactionSource, ripple(bounded = true)),
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
    active: Boolean,
    interactionSource: MutableInteractionSource
) {
    val iconColorOnBadge = FinancePyColors.surface()
    val inactiveColor = FinancePyColors.textSecondary()

    Box(
        modifier = Modifier
            .size(32.dp)
            .clip(CircleShape)
            .indication(interactionSource, ripple(bounded = true)),
        contentAlignment = Alignment.Center
    ) {
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
    // See AppBottomNavMoreItem: touch target is the full item, ripple is
    // scoped to the icon circle via this shared interactionSource.
    val interactionSource = remember { MutableInteractionSource() }

    Column(
        modifier = modifier.selectable(
            selected = active,
            interactionSource = interactionSource,
            indication = null,
            onClick = onClick
        ),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        AppBottomNavItemIcon(item = item, active = active, interactionSource = interactionSource)
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
