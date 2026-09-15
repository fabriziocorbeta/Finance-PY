package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.UploadFile
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UpayImportScreen(
    viewModel: UpayImportViewModel,
    onPickCsvFile: (onPicked: (ByteArray, String) -> Unit) -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Importar liquidación Upay", style = MaterialTheme.typography.titleLarge) },
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Subí el CSV que exporta Upay con las liquidaciones de tarjeta. Se registra el ingreso y la comisión automáticamente, y se concilia con ventas ya cargadas cuando coinciden.",
                style = MaterialTheme.typography.bodyMedium,
                color = FinancePyColors.textSecondary()
            )

            if (state.error != null) {
                Text(
                    text = state.error ?: "",
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
                    value = selectedAccount?.name ?: "Seleccionar Cuenta",
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Cuenta donde se depositó") },
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
                onClick = { onPickCsvFile { bytes, name -> viewModel.onFilePicked(bytes, name) } },
                modifier = Modifier.fillMaxWidth(),
                enabled = !state.isUploading
            ) {
                Icon(Icons.Default.UploadFile, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text(state.pickedFileName ?: "Seleccionar archivo CSV")
            }

            Button(
                onClick = { viewModel.upload() },
                modifier = Modifier.fillMaxWidth(),
                enabled = !state.isUploading && state.pickedFileBytes != null && state.selectedAccountId.isNotBlank()
            ) {
                if (state.isUploading) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                } else {
                    Text("Subir e importar")
                }
            }

            state.result?.let { result ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            when (result.status) {
                                "complete" -> Icon(Icons.Default.CheckCircle, contentDescription = null, tint = FinancePyColors.success())
                                "failed" -> Icon(Icons.Default.Error, contentDescription = null, tint = FinancePyColors.destructive())
                                else -> CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = when (result.status) {
                                    "complete" -> "Liquidación importada"
                                    "failed" -> "Falló la importación"
                                    else -> "Procesando en segundo plano…"
                                },
                                style = MaterialTheme.typography.titleMedium,
                                color = FinancePyColors.textPrimary()
                            )
                        }

                        result.stats?.let { stats ->
                            Text(
                                text = "${stats.rows_count} liquidaciones detectadas",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                        }

                        if (result.status == "importing") {
                            Text(
                                text = "Puede tardar unos minutos. Volvé a entrar a esta pantalla para ver el resultado final.",
                                style = MaterialTheme.typography.bodySmall,
                                color = FinancePyColors.textSecondary()
                            )
                        }

                        if (result.error != null) {
                            Text(
                                text = result.error,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }

                        TextButton(onClick = { viewModel.dismissResult() }) {
                            Text("Importar otro archivo")
                        }
                    }
                }
            }
        }
    }
}
