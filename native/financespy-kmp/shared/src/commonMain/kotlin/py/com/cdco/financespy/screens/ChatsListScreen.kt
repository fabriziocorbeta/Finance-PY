package py.com.cdco.financespy.screens

import kotlinx.coroutines.flow.StateFlow

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatsListScreen(
    viewModel: ChatsListViewModel,
    onChatClick: (String) -> Unit,
    onNewChatClick: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    val primary = FinancePyColors.buttonBgPrimary()
    val surface = FinancePyColors.surface()
    val textPrimary = FinancePyColors.textPrimary()
    val textSecondary = FinancePyColors.textSecondary()
    val surfaceHover = FinancePyColors.containerHover()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Asistente IA", style = MaterialTheme.typography.titleLarge) }
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onNewChatClick,
                containerColor = primary,
                contentColor = surface
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Nuevo chat")
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().padding(paddingValues)) {
            if (state.isLoading && state.chats.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            } else if (state.error != null && state.chats.isEmpty()) {
                Text(
                    text = state.error!!,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.align(Alignment.Center).padding(16.dp)
                )
            } else if (state.chats.isEmpty()) {
                Column(
                    modifier = Modifier.align(Alignment.Center).padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Filled.SmartToy,
                        contentDescription = null,
                        modifier = Modifier.size(64.dp),
                        tint = textSecondary
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "No tienes chats todavía",
                        style = MaterialTheme.typography.titleMedium,
                        color = textPrimary
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Preguntame sobre tus finanzas, transacciones o pedime ayuda para organizar tu presupuesto.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = textSecondary,
                        textAlign = androidx.compose.ui.text.style.TextAlign.Center
                    )
                    Spacer(modifier = Modifier.height(24.dp))
                    Button(onClick = onNewChatClick) {
                        Text("Nuevo chat")
                    }
                }
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(state.chats) { chat ->
                        Card(
                            modifier = Modifier.fillMaxWidth().clickable { onChatClick(chat.id) },
                            colors = CardDefaults.cardColors(containerColor = surfaceHover)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                Text(
                                    text = chat.title ?: "Nuevo chat",
                                    style = MaterialTheme.typography.titleMedium,
                                    color = textPrimary
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceBetween
                                ) {
                                    val count = chat.message_count ?: 0
                                    Text(
                                        text = "$count mensajes",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = textSecondary
                                    )
                                    if (chat.last_message_at != null) {
                                        Text(
                                            text = chat.last_message_at.take(10), // Simplistic date parsing
                                            style = MaterialTheme.typography.bodySmall,
                                            color = textSecondary
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
