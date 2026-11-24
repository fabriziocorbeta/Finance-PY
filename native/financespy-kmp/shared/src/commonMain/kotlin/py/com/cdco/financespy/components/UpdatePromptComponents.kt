package py.com.cdco.financespy.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.UpdateRequirement

/**
 * Full-screen, non-dismissible gate shown instead of the app UI when the
 * installed build is below `min_supported_version` / `min_build` or
 * `force_update == true`. Never renders financial data behind it.
 */
@Composable
fun ForceUpdateScreen(
    requirement: UpdateRequirement.ForceUpdate,
    onUpdateClick: (String) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = "Actualización obligatoria",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = "Esta versión de FinancePY ya no es compatible. Actualizá a la versión ${requirement.latestVersion} para seguir operando de forma segura.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center
                )
                if (!requirement.releaseNotes.isNullOrBlank()) {
                    Text(
                        text = requirement.releaseNotes,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                val targetUrl = requirement.updateUrl
                if (targetUrl != null) {
                    Button(
                        onClick = { onUpdateClick(targetUrl) },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Actualizar ahora")
                    }
                }
            }
        }
    }
}

/**
 * Non-intrusive, dismissible banner shown when a newer version is available
 * without blocking the user's workflow.
 */
@Composable
fun SoftUpdateBanner(
    requirement: UpdateRequirement.SoftUpdate,
    onUpdateClick: (String) -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
        shape = RoundedCornerShape(12.dp),
        color = MaterialTheme.colorScheme.primaryContainer
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.primaryContainer)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Nueva versión ${requirement.latestVersion} disponible",
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onPrimaryContainer
                )
                if (!requirement.releaseNotes.isNullOrBlank()) {
                    Text(
                        text = requirement.releaseNotes,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                val targetUrl = requirement.updateUrl
                if (targetUrl != null) {
                    TextButton(onClick = { onUpdateClick(targetUrl) }) {
                        Text("Actualizar")
                    }
                }
                TextButton(onClick = onDismiss) {
                    Text("Luego")
                }
            }
        }
    }
}
