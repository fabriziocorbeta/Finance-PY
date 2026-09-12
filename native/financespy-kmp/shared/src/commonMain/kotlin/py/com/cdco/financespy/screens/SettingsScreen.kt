package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onBack: () -> Unit,
    onLoggedOut: () -> Unit
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

private fun String.presence(): String? = if (this.isBlank()) null else this
