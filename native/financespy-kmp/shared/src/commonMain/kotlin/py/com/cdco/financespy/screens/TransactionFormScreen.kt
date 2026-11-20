package py.com.cdco.financespy.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.screens.components.TransactionLocationMap
import py.com.cdco.financespy.screens.components.parseHexColor
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppTextField
import py.com.cdco.financespy.utils.decodeByteArrayToImageBitmap

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun TransactionFormScreen(
    viewModel: TransactionFormViewModel,
    onSaved: () -> Unit,
    onCancel: () -> Unit,
    onPickInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null,
    onTakeInvoicePhoto: ((onPicked: (ByteArray, String, String) -> Unit) -> Unit)? = null
) {
    val state by viewModel.state.collectAsState()
    var showPhotoPreviewDialog by remember { mutableStateOf(false) }
    val decodedBitmap = remember(state.invoicePhotoBytes) {
        state.invoicePhotoBytes?.let { decodeByteArrayToImageBitmap(it) }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onCancel) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Volver",
                    tint = FinancePyColors.textPrimary()
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = if (viewModel.isEditMode) "Editar transacción" else "Nueva transacción",
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }

        if (state.isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = FinancePyColors.textPrimary())
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                AccountDropdown(
                    accounts = state.accounts,
                    selectedId = state.accountId,
                    onSelect = viewModel::updateAccountId
                )

                AppTextField(
                    value = state.name,
                    onValueChange = viewModel::updateName,
                    label = "Describe la transacción",
                    modifier = Modifier.fillMaxWidth()
                )

                Row(
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AppTextField(
                        value = state.amountText,
                        onValueChange = viewModel::updateAmountText,
                        label = "Importe",
                        modifier = Modifier.weight(1f)
                    )

                    NatureChip(
                        label = "Ingreso",
                        selected = state.nature == "income",
                        onClick = { viewModel.updateNature("income") }
                    )
                    NatureChip(
                        label = "Gasto",
                        selected = state.nature == "expense",
                        onClick = { viewModel.updateNature("expense") }
                    )
                }

                AppTextField(
                    value = state.date,
                    onValueChange = viewModel::updateDate,
                    label = "Fecha (AAAA-MM-DD)",
                    modifier = Modifier.fillMaxWidth()
                )

                CategoryDropdown(
                    categories = state.categories,
                    selectedId = state.categoryId,
                    onSelect = viewModel::updateCategoryId
                )

                MerchantDropdown(
                    merchants = state.merchants,
                    selectedId = state.merchantId,
                    onSelect = viewModel::updateMerchantId
                )

                if (state.tags.isNotEmpty()) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = "Etiquetas",
                            style = MaterialTheme.typography.labelMedium,
                            color = FinancePyColors.textSecondary()
                        )
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            state.tags.forEach { tag ->
                                val selected = state.selectedTagIds.contains(tag.id)
                                FilterChip(
                                    selected = selected,
                                    onClick = { viewModel.toggleTag(tag.id) },
                                    label = { Text(tag.name) },
                                    colors = FilterChipDefaults.filterChipColors(
                                        containerColor = FinancePyColors.container(),
                                        labelColor = FinancePyColors.textPrimary(),
                                        selectedContainerColor = FinancePyColors.buttonBgPrimary(),
                                        selectedLabelColor = FinancePyColors.surface()
                                    )
                                )
                            }
                        }
                    }
                }

                AppTextField(
                    value = state.notes,
                    onValueChange = viewModel::updateNotes,
                    label = "Introduce una nota",
                    modifier = Modifier.fillMaxWidth()
                )

                // Only present for transactions the Wallet notification
                // pipeline captured with the device-location toggle on; null
                // for everything else, nothing renders here then.
                state.location?.let { location ->
                    TransactionLocationMap(location = location)
                }

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = "Factura / Comprobante",
                        style = MaterialTheme.typography.labelMedium,
                        color = FinancePyColors.textSecondary()
                    )

                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = FinancePyColors.container())
                    ) {
                        Column(
                            modifier = Modifier.padding(16.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            val hasPhoto = state.invoicePhotoName != null || state.invoicePhotoBytes != null
                            if (hasPhoto) {
                                if (decodedBitmap != null) {
                                    Image(
                                        bitmap = decodedBitmap,
                                        contentDescription = "Vista previa de factura",
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(180.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .clickable { showPhotoPreviewDialog = true }
                                    )
                                }
                                if (state.invoicePhotoName != null) {
                                    Text(
                                        text = state.invoicePhotoName ?: "",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = FinancePyColors.textSecondary()
                                    )
                                }
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    OutlinedButton(
                                        onClick = {
                                            onTakeInvoicePhoto?.invoke { bytes, name, mime ->
                                                viewModel.selectInvoicePhoto(bytes, name, mime)
                                            }
                                        },
                                        modifier = Modifier.weight(1f),
                                        enabled = !state.isSaving
                                    ) {
                                        Text("Tomar otra foto")
                                    }
                                    OutlinedButton(
                                        onClick = {
                                            onPickInvoicePhoto?.invoke { bytes, name, mime ->
                                                viewModel.selectInvoicePhoto(bytes, name, mime)
                                            }
                                        },
                                        modifier = Modifier.weight(1f),
                                        enabled = !state.isSaving
                                    ) {
                                        Text("Cambiar archivo")
                                    }
                                }
                                TextButton(
                                    onClick = { viewModel.clearInvoicePhoto() },
                                    enabled = !state.isSaving,
                                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error)
                                ) {
                                    Text("Quitar factura")
                                }
                            } else {
                                Text(
                                    text = "Adjuntá una foto o PDF de la factura o comprobante de compra",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textSecondary()
                                )
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                                ) {
                                    Button(
                                        onClick = {
                                            onTakeInvoicePhoto?.invoke { bytes, name, mime ->
                                                viewModel.selectInvoicePhoto(bytes, name, mime)
                                            }
                                        },
                                        modifier = Modifier.weight(1f),
                                        enabled = !state.isSaving
                                    ) {
                                        Text("Tomar foto")
                                    }
                                    OutlinedButton(
                                        onClick = {
                                            onPickInvoicePhoto?.invoke { bytes, name, mime ->
                                                viewModel.selectInvoicePhoto(bytes, name, mime)
                                            }
                                        },
                                        modifier = Modifier.weight(1f),
                                        enabled = !state.isSaving
                                    ) {
                                        Text("Elegir archivo")
                                    }
                                }
                            }
                        }
                    }
                }

                AppButton(
                    text = when {
                        state.isSaving -> "Guardando..."
                        viewModel.isEditMode -> "Guardar"
                        else -> "Añadir transacción"
                    },
                    onClick = { viewModel.save(onSaved) },
                    enabled = !state.isSaving,
                    modifier = Modifier.fillMaxWidth()
                )

                state.error?.let {
                    Text(
                        text = "Error: $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.destructive()
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))
            }
        }
    }

    if (showPhotoPreviewDialog && decodedBitmap != null) {
        Dialog(
            onDismissRequest = { showPhotoPreviewDialog = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.9f))
                    .clickable { showPhotoPreviewDialog = false }
                    .padding(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Image(
                    bitmap = decodedBitmap,
                    contentDescription = "Factura en pantalla completa",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }
}

@Composable
private fun NatureChip(label: String, selected: Boolean, onClick: () -> Unit) {
    FilterChip(
        selected = selected,
        onClick = onClick,
        label = { Text(label) },
        colors = FilterChipDefaults.filterChipColors(
            containerColor = FinancePyColors.container(),
            labelColor = FinancePyColors.textPrimary(),
            selectedContainerColor = FinancePyColors.buttonBgPrimary(),
            selectedLabelColor = FinancePyColors.surface()
        )
    )
}

@Composable
private fun AccountDropdown(
    accounts: List<AccountDto>,
    selectedId: String?,
    onSelect: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedAccount = accounts.find { it.id == selectedId }

    Column {
        Text(
            text = "Cuenta",
            style = MaterialTheme.typography.labelMedium,
            color = FinancePyColors.textSecondary()
        )
        Box {
            DropdownTrigger(
                text = selectedAccount?.name ?: "Selecciona una cuenta",
                onClick = { expanded = true }
            )
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                accounts.forEach { account ->
                    DropdownMenuItem(
                        text = { Text(account.name) },
                        onClick = {
                            expanded = false
                            onSelect(account.id)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun CategoryDropdown(
    categories: List<CategoryDto>,
    selectedId: String?,
    onSelect: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedCategory = categories.find { it.id == selectedId }

    Column {
        Text(
            text = "Categoría",
            style = MaterialTheme.typography.labelMedium,
            color = FinancePyColors.textSecondary()
        )
        Box {
            DropdownTrigger(
                text = selectedCategory?.name ?: "Selecciona una categoría",
                leading = selectedCategory?.let { { ColorDot(it.color) } },
                onClick = { expanded = true }
            )
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(
                    text = { Text("(ninguno)") },
                    onClick = {
                        expanded = false
                        onSelect(null)
                    }
                )
                categories.forEach { category ->
                    DropdownMenuItem(
                        text = { Text(category.name) },
                        leadingIcon = { ColorDot(category.color) },
                        onClick = {
                            expanded = false
                            onSelect(category.id)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun MerchantDropdown(
    merchants: List<MerchantDto>,
    selectedId: String?,
    onSelect: (String?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedMerchant = merchants.find { it.id == selectedId }

    Column {
        Text(
            text = "Comerciante",
            style = MaterialTheme.typography.labelMedium,
            color = FinancePyColors.textSecondary()
        )
        Box {
            DropdownTrigger(
                text = selectedMerchant?.name ?: "Selecciona un comerciante",
                onClick = { expanded = true }
            )
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(
                    text = { Text("(ninguno)") },
                    onClick = {
                        expanded = false
                        onSelect(null)
                    }
                )
                merchants.forEach { merchant ->
                    DropdownMenuItem(
                        text = { Text(merchant.name) },
                        onClick = {
                            expanded = false
                            onSelect(merchant.id)
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun DropdownTrigger(
    text: String,
    onClick: () -> Unit,
    leading: (@Composable () -> Unit)? = null
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .border(width = 1.dp, color = FinancePyColors.borderSecondary(), shape = RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            if (leading != null) {
                leading()
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(text = text, color = FinancePyColors.textPrimary())
        }
        Icon(
            imageVector = Icons.Default.ArrowDropDown,
            contentDescription = null,
            tint = FinancePyColors.textSecondary()
        )
    }
}

@Composable
private fun ColorDot(hexColor: String) {
    Box(
        modifier = Modifier
            .size(10.dp)
            .clip(CircleShape)
            .background(parseHexColor(hexColor))
    )
}
