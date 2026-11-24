package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.google.android.gms.maps.model.CameraPosition
import com.google.android.gms.maps.model.LatLng
import com.google.maps.android.compose.GoogleMap
import com.google.maps.android.compose.MapUiSettings
import com.google.maps.android.compose.Marker
import com.google.maps.android.compose.MarkerState
import com.google.maps.android.compose.rememberCameraPositionState
import py.com.cdco.financespy.api.dto.TransactionLocationDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import kotlin.math.roundToLong

private fun formatCoordinate(value: Double): String {
    val scaled = (value * 100_000.0).roundToLong()
    val sign = if (scaled < 0) "-" else ""
    val absScaled = kotlin.math.abs(scaled)
    val whole = absScaled / 100_000
    val frac = (absScaled % 100_000).toString().padStart(5, '0')
    return "$sign$whole.$frac"
}

// Apple Pay / Google Pay style location card for a transaction.
@Composable
fun TransactionLocationMap(location: TransactionLocationDto) {
    val position = LatLng(location.latitude, location.longitude)
    val cameraPositionState = rememberCameraPositionState(key = "${location.latitude},${location.longitude}") {
        this.position = CameraPosition.fromLatLngZoom(position, 16f)
    }
    val uriHandler = LocalUriHandler.current
    val mapsUrl = "https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}"

    AppCard {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = null,
                        tint = FinancePyColors.buttonBgPrimary(),
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "Ubicación de la operación",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.textPrimary()
                    )
                }
                Text(
                    text = "Ver en Maps",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.buttonBgPrimary(),
                    modifier = Modifier.clickable { uriHandler.openUri(mapsUrl) }
                )
            }

            GoogleMap(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .clip(RoundedCornerShape(12.dp)),
                cameraPositionState = cameraPositionState,
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    scrollGesturesEnabled = false,
                    zoomGesturesEnabled = false,
                    rotationGesturesEnabled = false,
                    tiltGesturesEnabled = false,
                    mapToolbarEnabled = false
                ),
                onMapClick = { uriHandler.openUri(mapsUrl) }
            ) {
                Marker(state = MarkerState(position = position))
            }

            val coordsLabel = "${formatCoordinate(location.latitude)}, ${formatCoordinate(location.longitude)}"
            val footer = location.device?.takeIf { it.isNotBlank() }?.let { "$coordsLabel · $it" } ?: coordsLabel
            Text(
                text = footer,
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary()
            )
        }
    }
}
