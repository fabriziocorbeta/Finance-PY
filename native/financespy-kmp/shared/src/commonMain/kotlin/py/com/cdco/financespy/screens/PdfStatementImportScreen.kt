package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PictureAsPdf
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.utils.formatMoney

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PdfStatementImportScreen(
    viewModel: PdfStatementImportViewModel,
    onPickPdfFile: (onPicked: (ByteArray, String) -> Unit) -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Importar extracto", style = MaterialTheme.typography.titleLarge) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Volver")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FinancePyColors.container(),
                    titleContentColor = FinancePyColors.textPrimary()
                )
            )
        },
        containerColor = FinancePyColors.surface()
    ) { padding ->
        when (state.step) {
            PdfImportStep.PICK, PdfImportStep.PROCESSING -> PickStep(state, viewModel, onPickPdfFile, padding)
            PdfImportStep.REVIEW -> ReviewStep(state, viewModel, padding)
            PdfImportStep.DONE -> DoneStep(viewModel, onBack, padding)
        }
    }
}

@Composable
private fun PickStep(
    state: PdfStatementImportUiState,
    viewModel: PdfStatementImportViewModel,
    onPickPdfFile: (onPicked: (ByteArray, String) -> Unit) -> Unit,
    padding: PaddingValues
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Subí el PDF del extracto de tu banco o tarjeta de crédito. Una IA lee el documento y extrae las transacciones automáticamente -- vas a poder revisarlas antes de que se guarden.",
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textSecondary()
        )

        if (state.error != null) {
            Text(
                text = state.error,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium
            )
        }

        var accountExpanded by remember { mutableStateOf(false) }
        val selectedAccount = state.availableAccounts.find { it.id == state.selectedAccountId }

        ExposedDropdownMenuBox(
            expanded = accountExpanded,
            onExpandedChange = { accountExpanded = !accountExpanded }
        ) {
            OutlinedTextField(
                value = selectedAccount?.name ?: "Seleccionar cuenta",
                onValueChange = {},
                readOnly = true,
                label = { Text("Cuenta del extracto") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = accountExpanded) },
                modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
            )
            ExposedDropdownMenu(
                expanded = accountExpanded,
                onDismissRequest = { accountExpanded = false }
            ) {
                state.availableAccounts.forEach { acc ->
                    DropdownMenuItem(
                        text = { Text(acc.name) },
                        onClick = {
                            viewModel.selectAccount(acc.id)
                            accountExpanded = false
                        }
                    )
                }
            }
        }

        OutlinedButton(
            onClick = { onPickPdfFile { bytes, name -> viewModel.onFilePicked(bytes, name) } },
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isBusy
        ) {
            Icon(Icons.Default.PictureAsPdf, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text(state.pickedFileName ?: "Seleccionar PDF del extracto")
        }

        Button(
            onClick = { viewModel.upload() },
            modifier = Modifier.fillMaxWidth(),
            enabled = !state.isBusy && state.pickedFileBytes != null && state.selectedAccountId.isNotBlank()
        ) {
            if (state.isBusy) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
            } else {
                Text("Subir y procesar con IA")
            }
        }

        if (state.step == PdfImportStep.PROCESSING) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                Spacer(modifier = Modifier.width(12.dp))
                Text(
                    text = "Leyendo el extracto con IA… puede tardar un minuto.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textSecondary()
                )
            }
        }
    }
}

@Composable
private fun ReviewStep(
    state: PdfStatementImportUiState,
    viewModel: PdfStatementImportViewModel,
    padding: PaddingValues
) {
    Column(modifier = Modifier.fillMaxSize().padding(padding)) {
        Text(
            text = "${state.rows.size} transacciones encontradas. Revisá antes de confirmar -- la IA puede equivocarse.",
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textSecondary(),
            modifier = Modifier.padding(16.dp)
        )

        if (state.error != null) {
            Text(
                text = state.error,
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(state.rows) { row ->
                Card(colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = row.fields.name ?: "(sin nombre)",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textPrimary()
                            )
                            Text(
                                text = "${row.fields.date ?: "?"}${row.fields.category?.let { " · $it" } ?: ""}",
                                style = MaterialTheme.typography.bodySmall,
                                color = FinancePyColors.textSecondary()
                            )
                            if (!row.valid) {
                                Text(
                                    text = row.errors.joinToString(", "),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.error
                                )
                            }
                        }
                        Text(
                            text = formatMoney(
                                row.fields.amount?.toDoubleOrNull() ?: 0.0,
                                row.fields.currency
                            ),
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textPrimary()
                        )
                    }
                }
            }
        }

        Button(
            onClick = { viewModel.confirm() },
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            enabled = !state.isBusy
        ) {
            if (state.isBusy) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
            } else {
                Text("Confirmar e importar ${state.rows.size} transacciones")
            }
        }
    }
}

@Composable
private fun DoneStep(viewModel: PdfStatementImportViewModel, onBack: () -> Unit, padding: PaddingValues) {
    Column(
        modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.CheckCircle,
            contentDescription = null,
            tint = FinancePyColors.success(),
            modifier = Modifier.size(48.dp)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Extracto importado",
            style = MaterialTheme.typography.titleMedium,
            color = FinancePyColors.textPrimary()
        )
        Spacer(modifier = Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = { viewModel.reset() }) {
                Text("Importar otro")
            }
            Button(onClick = onBack) {
                Text("Listo")
            }
        }
    }
}
