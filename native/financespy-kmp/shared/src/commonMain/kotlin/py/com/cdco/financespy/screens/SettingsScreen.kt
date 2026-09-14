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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Rule
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.FamilyExportDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    onLoggedOut: () -> Unit,
    onOpenNotificationSettings: (() -> Unit)? = null,
    onShareFile: ((ByteArray, String, String) -> Unit)? = null,
    onNavigateToRules: (() -> Unit)? = null,
    onNavigateToNavCustomization: (() -> Unit)? = null
) {
    val state by viewModel.uiState.collectAsState()
    var showLogoutDialog by remember { mutableStateOf(false) }

    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = {
                Text(
                    text = "¿Cerrar sesión?",
                    color = FinancePyColors.textPrimary()
                )
            },
            text = {
                Text(
                    text = "¿Estás seguro de que deseas cerrar sesión? Tendrás que volver a ingresar tus credenciales.",
                    color = FinancePyColors.textSecondary()
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showLogoutDialog = false
                        viewModel.logout(onLoggedOut)
                    }
                ) {
                    Text(
                        text = "Confirmar",
                        color = FinancePyColors.destructive()
                    )
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { showLogoutDialog = false }
                ) {
                    Text(
                        text = "Cancelar",
                        color = FinancePyColors.textPrimary()
                    )
                }
            },
            containerColor = FinancePyColors.container(),
            titleContentColor = FinancePyColors.textPrimary(),
            textContentColor = FinancePyColors.textSecondary()
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Volver",
                    tint = FinancePyColors.textPrimary()
                )
            }
            Text(
                text = "Ajustes",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }

        if (state.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = FinancePyColors.buttonBgPrimary())
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp)
            ) {
                state.error?.let { err ->
                    item {
                        Text(
                            text = err,
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.destructive()
                        )
                    }
                }

                item {
                    Text(
                        text = "Perfil",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    AppCard {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            val user = state.currentUser
                            val name = user?.display_name
                                ?: listOfNotNull(user?.first_name, user?.last_name).joinToString(" ").presence()
                                ?: user?.email
                                ?: "Sin información"

                            ProfileItem(label = "Nombre", value = name)
                            ProfileItem(label = "Email", value = user?.email ?: "-")
                            ProfileItem(label = "Rol", value = user?.role?.uppercase() ?: "-")
                        }
                    }
                }

                item {
                    Text(
                        text = "Familia${state.familyName?.let { " ($it)" } ?: ""}",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }

                if (state.familyMembers.isEmpty()) {
                    item {
                        AppCard {
                            Text(
                                text = "No hay otros miembros registrados",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary(),
                                modifier = Modifier.padding(16.dp)
                            )
                        }
                    }
                } else {
                    items(state.familyMembers) { member ->
                        AppCard {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    val name = member.display_name
                                        ?: listOfNotNull(member.first_name, member.last_name).joinToString(" ").presence()
                                        ?: member.email

                                    Text(
                                        text = name,
                                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                    if (name != member.email) {
                                        Text(
                                            text = member.email,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = FinancePyColors.textSecondary()
                                        )
                                    }
                                }
                                Text(
                                    text = member.role.uppercase(),
                                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.textSecondary(),
                                    modifier = Modifier.padding(start = 8.dp)
                                )
                            }
                        }
                    }
                }

                if (onNavigateToRules != null || onNavigateToNavCustomization != null) {
                    item {
                        Text(
                            text = "Navegación",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        AppCard {
                            Column(modifier = Modifier.fillMaxWidth()) {
                                if (onNavigateToRules != null) {
                                    SettingsNavRow(
                                        icon = Icons.Filled.Rule,
                                        label = "Reglas",
                                        onClick = onNavigateToRules
                                    )
                                }
                                if (onNavigateToNavCustomization != null) {
                                    SettingsNavRow(
                                        icon = Icons.Filled.Tune,
                                        label = "Personalizar navegación",
                                        onClick = onNavigateToNavCustomization
                                    )
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                    }
                }

                // Family Data Backup (Admin only)
                if (state.currentUser?.role.equals("admin", ignoreCase = true)) {
                    item {
                        Text(
                            text = "Copia de Seguridad (Backup)",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        AppCard {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(12.dp)
                            ) {
                                Text(
                                    text = "Genera una copia de seguridad completa de los datos de tu familia en un archivo ZIP (cuentas, transacciones, reglas, categorías y NDJSON).",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )

                                AppButton(
                                    text = if (state.isCreatingExport) "Generando backup..." else "Crear nuevo backup",
                                    onClick = { viewModel.createFamilyExport() },
                                    enabled = !state.isCreatingExport,
                                    variant = ButtonVariant.Primary,
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }
                    }

                    if (state.familyExports.isNotEmpty()) {
                        items(state.familyExports) { export ->
                            FamilyExportItem(
                                export = export,
                                isDownloading = state.downloadingExportId == export.id,
                                onDownload = {
                                    if (onShareFile != null) {
                                        viewModel.downloadAndShareExport(export, onShareFile)
                                    }
                                }
                            )
                        }
                    }
                }

                if (onOpenNotificationSettings != null) {
                    item {
                        Text(
                            text = "Captura de Wallet",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        AppCard {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                verticalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                Text(
                                    text = "Permite a FinancePY capturar automáticamente compras enviadas por Google Wallet al recibir la notificación del sistema.",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                AppButton(
                                    text = "Activar acceso a notificaciones",
                                    onClick = onOpenNotificationSettings,
                                    variant = ButtonVariant.Secondary,
                                    modifier = Modifier.fillMaxWidth()
                                )
                            }
                        }
                    }
                }

                item {
                    Spacer(modifier = Modifier.height(12.dp))
                    AppButton(
                        text = "Cerrar sesión",
                        onClick = { showLogoutDialog = true },
                        variant = ButtonVariant.Destructive,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsNavRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = label,
            tint = FinancePyColors.textSecondary(),
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textPrimary(),
            modifier = Modifier.weight(1f)
        )
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = FinancePyColors.textSubdued()
        )
    }
}

@Composable
private fun ProfileItem(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textSecondary()
        )
        Spacer(modifier = Modifier.width(16.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = FinancePyColors.textPrimary()
        )
    }
}

@Composable
private fun FamilyExportItem(
    export: FamilyExportDto,
    isDownloading: Boolean,
    onDownload: () -> Unit
) {
    AppCard {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = export.filename ?: "Copia de seguridad",
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.textPrimary()
                    )
                    Text(
                        text = export.created_at.take(19).replace("T", " "),
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                }

                val (statusText, statusColor) = when (export.status) {
                    "completed" -> "Completado" to FinancePyColors.success()
                    "failed" -> "Fallido" to FinancePyColors.destructive()
                    "processing" -> "Procesando..." to FinancePyColors.warning()
                    else -> "Pendiente..." to FinancePyColors.textSecondary()
                }

                Surface(
                    color = statusColor.copy(alpha = 0.15f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text(
                        text = statusText,
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                        color = statusColor,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                    )
                }
            }

            if (export.downloadable) {
                Spacer(modifier = Modifier.height(4.dp))
                AppButton(
                    text = if (isDownloading) "Descargando..." else "Descargar / Compartir",
                    onClick = onDownload,
                    enabled = !isDownloading,
                    variant = ButtonVariant.Secondary,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}

private fun String.presence(): String? = if (this.isBlank()) null else this
