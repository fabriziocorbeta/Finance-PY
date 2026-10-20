package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant

// Overlay simple (no ModalBottomSheet/Drawer de Material3 para minimizar
// superficie de API nueva) mostrando los ítems del pool completo que no
// están fijos en la barra inferior -- feature nueva, exclusiva de la app
// nativa, sin equivalente en la web.
//
// Se cierra de 2 formas garantizadas: botón X explícito en el header, o
// tocando el scrim fuera del panel -- el panel NO usa fillMaxSize() (bug
// previo: hacía que ocupara toda la pantalla y no dejaba scrim tocable para
// cerrar), solo fillMaxHeight() + un ancho fijo.
@Composable
fun AppHamburgerMenu(
    items: List<NavItem>,
    onItemClick: (NavItem) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    val variant = LocalUiVariant.current
    if (variant == UiVariant.IOS) {
        IosMoreSheet(
            items = items,
            onItemClick = onItemClick,
            onDismiss = onDismiss,
            modifier = modifier
        )
        return
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.4f))
            .clickable(onClick = onDismiss)
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight()
                .width(280.dp)
                .background(FinancePyColors.container())
                .statusBarsPadding()
                // Modifier vacío (sin onClick) solo para que los toques dentro
                // del panel no se propaguen como "click" al Box de atrás.
                .clickable(onClick = {}, enabled = true)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Más opciones",
                    style = MaterialTheme.typography.titleMedium,
                    color = FinancePyColors.textPrimary()
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Cerrar",
                        tint = FinancePyColors.textPrimary()
                    )
                }
            }
            if (items.isEmpty()) {
                Text(
                    text = "Todos los ítems ya están en la barra inferior.",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary(),
                    modifier = Modifier.padding(horizontal = 16.dp)
                )
            } else {
                LazyColumn {
                    items(items) { item ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onItemClick(item) }
                                .padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = item.icon,
                                contentDescription = item.label,
                                tint = FinancePyColors.textSecondary(),
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = item.label,
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textPrimary()
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun IosMoreSheet(
    items: List<NavItem>,
    onItemClick: (NavItem) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            // iOS dims the backdrop heavily behind a sheet so the content
            // underneath reads as out of focus rather than as competing text.
            // At 0.4 the dashboard was still legible through it, which is what
            // made the sheet feel transparent. The real backdrop blur that iOS
            // uses needs a screen-space shader Compose does not expose, so the
            // depth comes from dimming plus the sheet's own opaque surface.
            .background(Color.Black.copy(alpha = 0.72f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.BottomCenter
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                // Translucent on purpose -- that is the Liquid Glass look. It
                // stays readable because what is behind it is blurred (see the
                // NavHost in App.kt) and dimmed by the scrim, rather than
                // because the sheet itself is opaque.
                .iosLiquidGlass(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp), contrastBoost = 0.30f)
                .clickable(onClick = {}, enabled = true)
                .navigationBarsPadding()
                // The dock floats over this sheet rather than sitting beside
                // it, so a fixed 24.dp left the last entry (Flota) hidden
                // behind the bar -- visible but untappable, the same failure
                // the FAB screens hit. Clear the measured dock height instead.
                .padding(bottom = AppBottomNavOverlayClearance)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(width = 36.dp, height = 5.dp)
                        .clip(RoundedCornerShape(2.5.dp))
                        .background(FinancePyColors.borderPrimary())
                )
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Más",
                    style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                Text(
                    text = "Listo",
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.buttonBgPrimary(),
                    modifier = Modifier.clickable(onClick = onDismiss)
                )
            }

            if (items.isEmpty()) {
                Text(
                    text = "Todos los ítems están en la barra principal.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textSecondary(),
                    modifier = Modifier.padding(horizontal = 20.dp, vertical = 12.dp)
                )
            } else {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .iosLiquidGlass(RoundedCornerShape(14.dp))
                ) {
                    items.forEachIndexed { index, item ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onItemClick(item) }
                                .padding(horizontal = 16.dp, vertical = 13.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                imageVector = item.icon,
                                contentDescription = item.label,
                                tint = FinancePyColors.buttonBgPrimary(),
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = item.label,
                                style = MaterialTheme.typography.bodyLarge,
                                color = FinancePyColors.textPrimary(),
                                modifier = Modifier.weight(1f)
                            )
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                contentDescription = null,
                                tint = FinancePyColors.textSubdued(),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                        if (index < items.lastIndex) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 48.dp),
                                thickness = 0.5.dp,
                                color = FinancePyColors.borderSecondary()
                            )
                        }
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))
        }
    }
}
