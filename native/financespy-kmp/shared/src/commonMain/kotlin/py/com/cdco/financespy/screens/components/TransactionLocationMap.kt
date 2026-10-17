package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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

// Shows WHERE the device was when a Wallet-captured notification arrived --
// never the merchant's real location, the bank notification never carries
// coordinates. The label below the map says so explicitly so this never
// reads as an Apple-Pay-style "this is where you bought it" claim.
@Composable
fun TransactionLocationMap(location: TransactionLocationDto) {
    val position = LatLng(location.latitude, location.longitude)
    val cameraPositionState = rememberCameraPositionState {
        this.position = CameraPosition.fromLatLngZoom(position, 15f)
    }

    AppCard {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(
                text = "Ubicación aproximada (dispositivo)",
                style = MaterialTheme.typography.labelMedium,
                color = FinancePyColors.textSecondary()
            )
            GoogleMap(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp)
                    .clip(RoundedCornerShape(12.dp)),
                cameraPositionState = cameraPositionState,
                uiSettings = MapUiSettings(
                    zoomControlsEnabled = false,
                    scrollGesturesEnabled = false,
                    zoomGesturesEnabled = false,
                    rotationGesturesEnabled = false,
                    tiltGesturesEnabled = false
                )
            ) {
                Marker(state = MarkerState(position = position))
            }
            val deviceLabel = location.device
            Text(
                text = if (deviceLabel.isNullOrBlank()) {
                    "No es la ubicación del comercio, sino la del teléfono al momento de capturar la notificación."
                } else {
                    "No es la ubicación del comercio, sino la del teléfono ($deviceLabel) al momento de capturar la notificación."
                },
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary()
            )
        }
    }
}
