package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.api.dto.UpdateTransactionBody
import py.com.cdco.financespy.sync.currentIsoDate

data class TransactionFormState(
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null,
    val accountId: String? = null,
    val date: String = currentIsoDate(),
    val amountText: String = "",
    val nature: String = "expense",
    val name: String = "",
    val notes: String = "",
    val categoryId: String? = null,
    val merchantId: String? = null,
    val selectedTagIds: Set<String> = emptySet(),
    val accounts: List<AccountDto> = emptyList(),
    val categories: List<CategoryDto> = emptyList(),
    val merchants: List<MerchantDto> = emptyList(),
    val tags: List<TagDto> = emptyList()
)

class TransactionFormViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val transactionId: String?
) {
    val isEditMode: Boolean = transactionId != null

    private val _state = MutableStateFlow(TransactionFormState(isLoading = isEditMode))
    val state: StateFlow<TransactionFormState> = _state

    init {
        scope.launch {
            val accounts = runCatching { api.fetchAllAccounts() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(accounts = accounts)
        }
        scope.launch {
            val categories = runCatching { api.fetchCategories() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(categories = categories)
        }
        scope.launch {
            val merchants = runCatching { api.fetchMerchants() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(merchants = merchants)
        }
        scope.launch {
            val tags = runCatching { api.fetchTags() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(tags = tags)
        }

        if (transactionId != null) {
            scope.launch {
                runCatching { api.fetchTransaction(transactionId) }
                    .onSuccess { detail ->
                        _state.value = _state.value.copy(
                            isLoading = false,
                            accountId = detail.account.id,
                            date = detail.date,
                            amountText = detail.amount,
                            nature = if (detail.classification == "income") "income" else "expense",
                            name = detail.name,
                            notes = detail.notes.orEmpty(),
                            categoryId = detail.category?.id,
                            merchantId = detail.merchant?.id,
                            selectedTagIds = detail.tags.map { it.id }.toSet()
                        )
                    }
                    .onFailure { e ->
                        _state.value = _state.value.copy(
                            isLoading = false,
                            error = e.message ?: "Error al cargar la transacción"
                        )
                    }
            }
        }
    }

    fun updateAccountId(value: String?) { _state.value = _state.value.copy(accountId = value) }
    fun updateDate(value: String) { _state.value = _state.value.copy(date = value) }
    fun updateAmountText(value: String) { _state.value = _state.value.copy(amountText = value) }
    fun updateNature(value: String) { _state.value = _state.value.copy(nature = value) }
    fun updateName(value: String) { _state.value = _state.value.copy(name = value) }
    fun updateNotes(value: String) { _state.value = _state.value.copy(notes = value) }
    fun updateCategoryId(value: String?) { _state.value = _state.value.copy(categoryId = value) }
    fun updateMerchantId(value: String?) { _state.value = _state.value.copy(merchantId = value) }

    fun toggleTag(id: String) {
        val current = _state.value.selectedTagIds.toMutableSet()
        if (current.contains(id)) {
            current.remove(id)
        } else {
            current.add(id)
        }
        _state.value = _state.value.copy(selectedTagIds = current)
    }

    fun save(onSaved: () -> Unit) {
        val s = _state.value
        if (s.accountId == null) {
            _state.value = s.copy(error = "Seleccioná una cuenta")
            return
        }
        if (s.name.isBlank()) {
            _state.value = s.copy(error = "El nombre no puede estar vacío")
            return
        }
        if (s.amountText.isBlank() || s.amountText.toDoubleOrNull() == null || s.amountText.toDouble() <= 0) {
            _state.value = s.copy(error = "Ingresá un importe válido mayor a cero")
            return
        }

        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)

            val result = if (transactionId != null) {
                val body = UpdateTransactionBody(
                    account_id = s.accountId,
                    date = s.date,
                    amount = s.amountText,
                    nature = s.nature,
                    name = s.name,
                    notes = s.notes.ifBlank { null },
                    category_id = s.categoryId,
                    merchant_id = s.merchantId,
                    tag_ids = s.selectedTagIds.toList()
                )
                runCatching { api.updateTransaction(transactionId, body) }
            } else {
                val body = CreateTransactionBody(
                    account_id = s.accountId,
                    date = s.date,
                    amount = s.amountText,
                    nature = s.nature,
                    name = s.name,
                    notes = s.notes.ifBlank { null },
                    category_id = s.categoryId,
                    merchant_id = s.merchantId,
                    tag_ids = s.selectedTagIds.toList()
                )
                runCatching { api.createTransaction(body) }
            }

            result
                .onSuccess {
                    _state.value = _state.value.copy(isSaving = false)
                    onSaved()
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al guardar")
                }
        }
    }
}
