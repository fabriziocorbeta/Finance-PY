package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.UpdateFamilyAttributesDto
import py.com.cdco.financespy.api.dto.UpdateUserBody
import py.com.cdco.financespy.sync.currentIsoDate

data class OnboardingState(
    val currentStep: Int = 1,
    val firstName: String = "",
    val lastName: String = "",
    val moniker: String = "Family",
    val familyName: String = "",
    val country: String = "PY",
    val theme: String = "system",
    val locale: String = "es",
    val currency: String = "PYG",
    val dateFormat: String = "%d/%m/%Y",
    val selectedGoals: Set<String> = emptySet(),
    val isInvited: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null
)

class OnboardingViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi
) {
    private val _state = MutableStateFlow(OnboardingState())
    val state: StateFlow<OnboardingState> = _state.asStateFlow()

    init {
        loadInitialData()
    }

    private fun loadInitialData() {
        scope.launch {
            _state.update { it.copy(isLoading = true) }
            try {
                val settings = api.fetchFamilySettings()
                val user = settings.current_user
                val isInvited = user?.is_invited == true
                _state.update {
                    it.copy(
                        firstName = user?.first_name.orEmpty(),
                        lastName = user?.last_name.orEmpty(),
                        moniker = settings.moniker ?: "Family",
                        familyName = settings.name.orEmpty(),
                        country = settings.country ?: "PY",
                        theme = user?.theme ?: "system",
                        locale = settings.locale.ifBlank { "es" },
                        currency = settings.currency.ifBlank { "PYG" },
                        dateFormat = settings.date_format.ifBlank { "%d/%m/%Y" },
                        selectedGoals = user?.goals?.toSet() ?: emptySet(),
                        isInvited = isInvited,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false) }
            }
        }
    }

    fun updateFirstName(name: String) {
        _state.update { it.copy(firstName = name, error = null) }
    }

    fun updateLastName(name: String) {
        _state.update { it.copy(lastName = name, error = null) }
    }

    fun updateMoniker(moniker: String) {
        _state.update { it.copy(moniker = moniker) }
    }

    fun updateFamilyName(name: String) {
        _state.update { it.copy(familyName = name) }
    }

    fun updateCountry(country: String) {
        _state.update { it.copy(country = country) }
    }

    fun updateTheme(theme: String) {
        _state.update { it.copy(theme = theme) }
    }

    fun updateLocale(locale: String) {
        _state.update { it.copy(locale = locale) }
    }

    fun updateCurrency(currency: String) {
        _state.update { it.copy(currency = currency) }
    }

    fun updateDateFormat(format: String) {
        _state.update { it.copy(dateFormat = format) }
    }

    fun toggleGoal(goalKey: String) {
        _state.update { s ->
            val updated = if (s.selectedGoals.contains(goalKey)) {
                s.selectedGoals - goalKey
            } else {
                s.selectedGoals + goalKey
            }
            s.copy(selectedGoals = updated)
        }
    }

    fun nextStep() {
        val current = _state.value.currentStep
        if (current == 1) {
            if (_state.value.firstName.isBlank() || _state.value.lastName.isBlank()) {
                _state.update { it.copy(error = "Por favor completá tu nombre y apellido") }
                return
            }
            if (!_state.value.isInvited && _state.value.familyName.isBlank()) {
                _state.update { it.copy(error = "Por favor completá el nombre de tu familia/grupo") }
                return
            }
        }
        _state.update { it.copy(currentStep = (current + 1).coerceAtMost(3), error = null) }
    }

    fun prevStep() {
        val current = _state.value.currentStep
        _state.update { it.copy(currentStep = (current - 1).coerceAtLeast(1), error = null) }
    }

    fun completeOnboarding(onSuccess: () -> Unit) {
        scope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            val now = currentIsoDate()
            val currentVal = _state.value

            val familyAttrs = UpdateFamilyAttributesDto(
                moniker = if (!currentVal.isInvited) currentVal.moniker else null,
                name = if (!currentVal.isInvited) currentVal.familyName else null,
                country = if (!currentVal.isInvited) currentVal.country else null,
                currency = currentVal.currency,
                locale = currentVal.locale,
                date_format = currentVal.dateFormat
            )

            val body = UpdateUserBody(
                first_name = currentVal.firstName,
                last_name = currentVal.lastName,
                theme = currentVal.theme,
                locale = currentVal.locale,
                goals = currentVal.selectedGoals.toList(),
                set_onboarding_preferences_at = now,
                set_onboarding_goals_at = now,
                onboarded_at = now,
                family_attributes = familyAttrs
            )

            try {
                api.updateUser(body)
                _state.update { it.copy(isLoading = false) }
                onSuccess()
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message ?: "Error al guardar el onboarding") }
            }
        }
    }
}
