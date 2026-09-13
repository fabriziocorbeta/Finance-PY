package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppTextField

data class GoalOption(
    val key: String,
    val title: String
)

val GOAL_OPTIONS = listOf(
    GoalOption("unified_accounts", "Ver todas mis cuentas en un solo lugar"),
    GoalOption("cashflow", "Entender el flujo de caja y los gastos"),
    GoalOption("budgeting", "Gestionar planes financieros y presupuestos"),
    GoalOption("partner", "Gestionar finanzas con mi pareja"),
    GoalOption("investments", "Seguir las inversiones"),
    GoalOption("ai_insights", "Dejar que la IA me ayude a entender mis finanzas"),
    GoalOption("optimization", "Analizar y optimizar cuentas"),
    GoalOption("reduce_stress", "Reducir el estrés financiero o la ansiedad")
)

@Composable
fun OnboardingScreen(
    viewModel: OnboardingViewModel,
    onComplete: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    val scrollState = rememberScrollState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
            .padding(24.dp)
            .verticalScroll(scrollState),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // Header Title
        Text(
            text = when (state.currentStep) {
                1 -> "Configuremos tu cuenta"
                2 -> "Configura tus preferencias"
                else -> "¿Qué te trae por aquí?"
            },
            style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
            color = FinancePyColors.textPrimary(),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = when (state.currentStep) {
                1 -> "Primero, completemos tu perfil."
                2 -> "Configuremos tus preferencias."
                else -> "Selecciona uno o más objetivos que tienes con la herramienta."
            },
            style = MaterialTheme.typography.bodyMedium,
            color = FinancePyColors.textSecondary(),
            textAlign = TextAlign.Center
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Step Indicator
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            (1..3).forEach { step ->
                val isActive = step == state.currentStep
                val isCompleted = step < state.currentStep

                Box(
                    modifier = Modifier
                        .height(8.dp)
                        .weight(1f)
                        .clip(RoundedCornerShape(4.dp))
                        .background(
                            when {
                                isActive -> FinancePyColors.buttonBgPrimary()
                                isCompleted -> FinancePyColors.buttonBgPrimary().copy(alpha = 0.5f)
                                else -> FinancePyColors.container()
                            }
                        )
                )

                if (step < 3) {
                    Spacer(modifier = Modifier.width(8.dp))
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        state.error?.let { err ->
            Text(
                text = err,
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.destructive(),
                modifier = Modifier.padding(bottom = 16.dp)
            )
        }

        when (state.currentStep) {
            1 -> StepOneProfileAndFamily(state, viewModel)
            2 -> StepTwoPreferences(state, viewModel)
            3 -> StepThreeGoals(state, viewModel)
        }

        Spacer(modifier = Modifier.weight(1f))
        Spacer(modifier = Modifier.height(24.dp))

        // Navigation Buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (state.currentStep > 1) {
                AppButton(
                    text = "Atrás",
                    onClick = { viewModel.prevStep() }
                )
            } else {
                Spacer(modifier = Modifier.width(1.dp))
            }

            if (state.isLoading) {
                CircularProgressIndicator(color = FinancePyColors.buttonBgPrimary())
            } else if (state.currentStep < 3) {
                AppButton(
                    text = "Continuar",
                    onClick = { viewModel.nextStep() }
                )
            } else {
                AppButton(
                    text = "Completar",
                    onClick = {
                        viewModel.completeOnboarding(onSuccess = onComplete)
                    }
                )
            }
        }
    }
}

@Composable
private fun StepOneProfileAndFamily(
    state: OnboardingState,
    viewModel: OnboardingViewModel
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        AppTextField(
            value = state.firstName,
            onValueChange = { viewModel.updateFirstName(it) },
            label = "Nombre",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(16.dp))

        AppTextField(
            value = state.lastName,
            onValueChange = { viewModel.updateLastName(it) },
            label = "Apellido",
            modifier = Modifier.fillMaxWidth()
        )

        if (!state.isInvited) {
            Spacer(modifier = Modifier.height(20.dp))

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(FinancePyColors.container())
                    .padding(16.dp)
            ) {
                Text(
                    text = "Usaré la app con...",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { viewModel.updateMoniker("Family") }
                ) {
                    RadioButton(
                        selected = state.moniker == "Family",
                        onClick = { viewModel.updateMoniker("Family") },
                        colors = RadioButtonDefaults.colors(selectedColor = FinancePyColors.buttonBgPrimary())
                    )
                    Text(
                        text = "Miembros de la familia",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textPrimary()
                    )
                }

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { viewModel.updateMoniker("Group") }
                ) {
                    RadioButton(
                        selected = state.moniker == "Group",
                        onClick = { viewModel.updateMoniker("Group") },
                        colors = RadioButtonDefaults.colors(selectedColor = FinancePyColors.buttonBgPrimary())
                    )
                    Text(
                        text = "Un grupo de personas (empresa, club, etc.)",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textPrimary()
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                AppTextField(
                    value = state.familyName,
                    onValueChange = { viewModel.updateFamilyName(it) },
                    label = if (state.moniker == "Family") "Nombre del hogar" else "Nombre del grupo",
                    modifier = Modifier.fillMaxWidth()
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            AppTextField(
                value = state.country,
                onValueChange = { viewModel.updateCountry(it) },
                label = "País (código)",
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun StepTwoPreferences(
    state: OnboardingState,
    viewModel: OnboardingViewModel
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        val themes = listOf("system" to "Sistema", "light" to "Claro", "dark" to "Oscuro")
        DropdownSelector(
            label = "Tema de color",
            currentValue = themes.find { it.first == state.theme }?.second ?: "Sistema",
            options = themes,
            onSelect = { viewModel.updateTheme(it) }
        )

        Spacer(modifier = Modifier.height(16.dp))

        val locales = listOf("es" to "Español", "en" to "English")
        DropdownSelector(
            label = "Idioma",
            currentValue = locales.find { it.first == state.locale }?.second ?: "Español",
            options = locales,
            onSelect = { viewModel.updateLocale(it) }
        )

        Spacer(modifier = Modifier.height(16.dp))

        val currencies = listOf(
            "PYG" to "Guaraní (PYG)",
            "USD" to "Dólar (USD)",
            "ARS" to "Peso Argentino (ARS)",
            "BRL" to "Real (BRL)",
            "EUR" to "Euro (EUR)"
        )
        DropdownSelector(
            label = "Moneda",
            currentValue = currencies.find { it.first == state.currency }?.second ?: "Guaraní (PYG)",
            options = currencies,
            onSelect = { viewModel.updateCurrency(it) }
        )

        Spacer(modifier = Modifier.height(16.dp))

        val formats = listOf(
            "%d/%m/%Y" to "DD/MM/YYYY",
            "%Y-%m-%d" to "YYYY-MM-DD",
            "%m/%d/%Y" to "MM/DD/YYYY"
        )
        DropdownSelector(
            label = "Formato de fecha",
            currentValue = formats.find { it.first == state.dateFormat }?.second ?: "DD/MM/YYYY",
            options = formats,
            onSelect = { viewModel.updateDateFormat(it) }
        )
    }
}

@Composable
private fun StepThreeGoals(
    state: OnboardingState,
    viewModel: OnboardingViewModel
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        GOAL_OPTIONS.forEach { option ->
            val isSelected = state.selectedGoals.contains(option.key)

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (isSelected) FinancePyColors.container() else FinancePyColors.surface())
                    .border(
                        width = 1.dp,
                        color = if (isSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.container(),
                        shape = RoundedCornerShape(12.dp)
                    )
                    .clickable { viewModel.toggleGoal(option.key) }
                    .padding(16.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        text = option.title,
                        style = MaterialTheme.typography.bodyMedium.copy(
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                        ),
                        color = FinancePyColors.textPrimary(),
                        modifier = Modifier.weight(1f)
                    )
                    if (isSelected) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Icon(
                            imageVector = Icons.Default.Check,
                            contentDescription = null,
                            tint = FinancePyColors.buttonBgPrimary()
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DropdownSelector(
    label: String,
    currentValue: String,
    options: List<Pair<String, String>>,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = FinancePyColors.textSecondary()
        )
        Spacer(modifier = Modifier.height(4.dp))
        Box {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(FinancePyColors.container())
                    .clickable { expanded = true }
                    .padding(horizontal = 14.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = currentValue,
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.textPrimary()
                )
                Icon(
                    imageVector = Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = FinancePyColors.textSecondary()
                )
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                options.forEach { (key, title) ->
                    DropdownMenuItem(
                        text = {
                            Text(
                                text = title,
                                color = FinancePyColors.textPrimary()
                            )
                        },
                        onClick = {
                            expanded = false
                            onSelect(key)
                        }
                    )
                }
            }
        }
    }
}
