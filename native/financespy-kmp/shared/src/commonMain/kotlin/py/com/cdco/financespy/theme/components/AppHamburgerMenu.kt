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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.theme.FinancePyColors

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
