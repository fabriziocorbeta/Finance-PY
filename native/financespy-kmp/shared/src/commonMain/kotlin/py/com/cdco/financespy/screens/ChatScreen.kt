package py.com.cdco.financespy.screens

import kotlinx.coroutines.flow.StateFlow

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.api.dto.MessageDto

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel,
    onBackClick: () -> Unit,
    onNavigateToPdfImport: () -> Unit,
    chatId: String? = null
) {
    val state by viewModel.state.collectAsState()
    var inputText by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    // Auto-scroll to bottom when new messages arrive
    LaunchedEffect(state.messages.size) {
        if (state.messages.isNotEmpty()) {
            listState.animateScrollToItem(state.messages.size - 1)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (state.isNewChat) "Nuevo chat" else (state.title.takeIf { it.isNotBlank() } ?: "Chat"), style = MaterialTheme.typography.titleLarge) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = "Atrás")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier.fillMaxSize().padding(paddingValues)
        ) {
            // Error banner
            if (state.error != null) {
                Box(
                    modifier = Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.errorContainer).padding(8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(state.error!!, color = MaterialTheme.colorScheme.onErrorContainer, style = MaterialTheme.typography.bodySmall)
                }
            }

            // Message list
            Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
                if (state.isLoading && state.messages.isEmpty()) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        items(state.messages) { message ->
                            MessageBubble(message)
                        }

                        if (state.isSending) {
                            item {
                                Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                                }
                            }
                        }
                    }
                }
            }

            // Input area
            val textPrimary = FinancePyColors.textPrimary()
            val textSecondary = FinancePyColors.textSecondary()
            val surfaceHover = FinancePyColors.containerHover()
            val surface = FinancePyColors.surface()
            val primary = FinancePyColors.buttonBgPrimary()
            val border = FinancePyColors.borderPrimary()

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(surface)
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // PDF Import Button - matching the web app's "+" functionality
                IconButton(onClick = onNavigateToPdfImport) {
                    Icon(
                        Icons.Filled.Add,
                        contentDescription = "Importar extracto",
                        tint = textPrimary
                    )
                }

                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Escribe un mensaje...") },
                    maxLines = 4,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedContainerColor = surfaceHover,
                        unfocusedContainerColor = surfaceHover,
                        unfocusedBorderColor = border,
                        focusedBorderColor = primary
                    ),
                    shape = RoundedCornerShape(20.dp)
                )

                IconButton(
                    onClick = {
                        if (inputText.isNotBlank()) {
                            viewModel.sendMessage(inputText)
                            inputText = ""
                        }
                    },
                    enabled = inputText.isNotBlank() && !state.isSending
                ) {
                    Icon(
                        Icons.Filled.Send,
                        contentDescription = "Enviar",
                        tint = if (inputText.isNotBlank() && !state.isSending) textPrimary else textSecondary
                    )
                }
            }
        }
    }
}

@Composable
fun MessageBubble(message: MessageDto) {
    val isUser = message.role == "user"
    val primary = FinancePyColors.buttonBgPrimary()
    val surface = FinancePyColors.surface()
    val textPrimary = FinancePyColors.textPrimary()
    val textSecondary = FinancePyColors.textSecondary()
    val surfaceHover = FinancePyColors.containerHover()

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (isUser) Arrangement.End else Arrangement.Start
    ) {
        if (!isUser) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(primary),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.SmartToy, contentDescription = null, tint = surface, modifier = Modifier.size(20.dp))
            }
            Spacer(modifier = Modifier.width(8.dp))
        }

        Column(
            modifier = Modifier.weight(1f, fill = false).fillMaxWidth(0.85f)
        ) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(
                        topStart = 16.dp,
                        topEnd = 16.dp,
                        bottomStart = if (isUser) 16.dp else 4.dp,
                        bottomEnd = if (isUser) 4.dp else 16.dp
                    ))
                    .background(if (isUser) primary else surfaceHover)
                    .padding(12.dp)
            ) {
                Text(
                    text = message.content ?: (if (message.ai_response_status == "pending") "Pensando..." else ""),
                    color = if (isUser) surface else textPrimary,
                    style = MaterialTheme.typography.bodyLarge
                )
            }

            // Pending / Tool call indicators
            if (message.ai_response_status == "pending") {
                Text(
                    text = message.ai_response_message ?: "Generando respuesta...",
                    color = textSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 4.dp, start = 4.dp)
                )
            }

            val toolCalls = message.tool_calls
            if (!toolCalls.isNullOrEmpty()) {
                toolCalls.forEach { tool ->
                    Text(
                        text = "🛠️ Usó: ${tool.function_name ?: ""}",
                        color = textSecondary,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.padding(top = 4.dp, start = 4.dp)
                    )
                }
            }
        }

        if (isUser) {
            Spacer(modifier = Modifier.width(8.dp))
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(surfaceHover),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Person, contentDescription = null, tint = textPrimary, modifier = Modifier.size(20.dp))
            }
        }
    }
}
