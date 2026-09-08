package py.com.cdco.financespy.screens

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.components.parseHexColor
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.AppTextField
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun BudgetAllocationEditorScreen(
    viewModel: BudgetAllocationEditorViewModel,
    onSaved: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(uiState.saveSuccess) {
        if (uiState.saveSuccess) {
            onSaved()
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        // Navigation Header
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Volver",
                    tint = FinancePyColors.textPrimary()
                )
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Editá los presupuestos por categoría",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = FinancePyColors.textPrimary())
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Summary Card
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(
                                text = "Asignación total",
                                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                                color = FinancePyColors.textPrimary()
                            )
                            Spacer(modifier = Modifier.height(8.dp))

                            val progressFraction = (uiState.allocatedPercent / 100.0).toFloat().coerceIn(0f, 1f)
                            LinearProgressIndicator(
                                progress = { progressFraction },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(8.dp)
                                    .clip(RoundedCornerShape(4.dp)),
                                color = if (uiState.availableToAllocate < 0) FinancePyColors.destructive() else FinancePyColors.buttonBgPrimary(),
                                trackColor = FinancePyColors.borderSecondary()
                            )

                            Spacer(modifier = Modifier.height(8.dp))

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = if (uiState.availableToAllocate < 0) {
                                        "Superaste el presupuesto por ${uiState.currency} ${(-uiState.availableToAllocate).toInt()}"
                                    } else {
                                        "${uiState.allocatedPercent.toInt()}% asignado (${uiState.currency} ${uiState.totalAllocated.toInt()} / ${uiState.expectedIncome.toInt()})"
                                    },
                                    style = MaterialTheme.typography.bodySmall,
                                    color = if (uiState.availableToAllocate < 0) FinancePyColors.destructive() else FinancePyColors.textSecondary()
                                )

                                Text(
                                    text = "Disponible: ${uiState.currency} ${uiState.availableToAllocate.toInt()}",
                                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                                    color = if (uiState.availableToAllocate < 0) FinancePyColors.destructive() else FinancePyColors.textPrimary()
                                )
                            }
                        }
                    }
                }

                if (uiState.error != null) {
                    item {
                        Text(
                            text = uiState.error!!,
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.destructive()
                        )
                    }
                }

                // Category List Input
                items(uiState.categories, key = { it.id }) { category ->
                    val inputVal = uiState.inputs[category.id] ?: ""
                    val startIndent = if (category.isSubcategory) 24.dp else 0.dp
                    val categoryColor = parseHexColor(category.categoryColor)

                    AppCard(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(start = startIndent)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.weight(1f)
                            ) {
                                if (category.isSubcategory) {
                                    Icon(
                                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                        contentDescription = "Subcategoría",
                                        tint = FinancePyColors.textSecondary(),
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(4.dp))
                                }

                                Box(
                                    modifier = Modifier
                                        .size(12.dp)
                                        .clip(CircleShape)
                                        .background(categoryColor)
                                )
                                Spacer(modifier = Modifier.width(8.dp))

                                Column {
                                    Text(
                                        text = category.categoryName,
                                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                    if (category.isSubcategory && category.inheritsParentBudget && inputVal.isBlank()) {
                                        Text(
                                            text = "Compartido con la categoría principal",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = FinancePyColors.textSubdued()
                                        )
                                    }
                                }
                            }

                            Spacer(modifier = Modifier.width(12.dp))

                            AppTextField(
                                value = inputVal,
                                onValueChange = { viewModel.onInputChanged(category.id, it) },
                                label = if (category.isSubcategory && category.inheritsParentBudget) "Compartido" else uiState.currency,
                                modifier = Modifier.width(130.dp)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Action Button
            AppButton(
                text = if (uiState.isSaving) "Guardando..." else "Confirmar",
                onClick = { viewModel.saveAllocations() },
                variant = ButtonVariant.Primary,
                enabled = uiState.allocationsValid && !uiState.isSaving,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
