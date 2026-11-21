package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.FleetVehicleDto
import py.com.cdco.financespy.api.dto.InvoicePhotoDto
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.api.dto.TransactionFuelLogLineRequestDto
import py.com.cdco.financespy.api.dto.TransactionFuelLogRequestDto
import py.com.cdco.financespy.api.dto.TransactionLocationDto
import py.com.cdco.financespy.api.dto.UpdateTransactionBody
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineOutbox
import py.com.cdco.financespy.sync.centsToAmountText
import kotlinx.coroutines.flow.first
import py.com.cdco.financespy.sync.currentIsoDate

data class FuelLogFormLineState(
    val id: String? = null,
    val fuelType: String = "nafta",
    val brand: String = "Podium",
    val litersText: String = "",
    val costText: String = ""
)

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
    val tags: List<TagDto> = emptyList(),
    val fleetVehicles: List<FleetVehicleDto> = emptyList(),
    val location: TransactionLocationDto? = null,
    val capturedLatitude: Double? = null,
    val capturedLongitude: Double? = null,
    val isFuelLogEnabled: Boolean = false,
    val fuelLogVehicleId: String? = null,
    val fuelLogOdometer: String = "",
    val fuelLogNotes: String = "",
    val fuelLogLines: List<FuelLogFormLineState> = listOf(FuelLogFormLineState()),
    val invoicePhotoBytes: ByteArray? = null,
    val invoicePhotoName: String? = null,
    val invoicePhotoContentType: String? = null,
    val existingInvoicePhoto: InvoicePhotoDto? = null,
    val hasNewInvoicePhoto: Boolean = false,
    val removeExistingInvoicePhoto: Boolean = false
)

class TransactionFormViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val transactionId: String?,
    private val outbox: OfflineOutbox? = null,
    private val entryDao: EntryDao? = null,
    private val transactionDao: TransactionDao? = null
) {
    // Edit prefilled from the local copy: notes/tags are unknown there, so an
    // offline edit must not send them (it would wipe them on the server).
    private var partialEdit = false

    val isEditMode: Boolean = transactionId != null

    private val _state = MutableStateFlow(TransactionFormState(isLoading = isEditMode))
    val state: StateFlow<TransactionFormState> = _state

    init {
        scope.launch {
            val accounts = outbox?.cachedList("accounts", AccountDto.serializer()) { api.fetchAllAccounts() } ?: runCatching { api.fetchAllAccounts() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(accounts = accounts)
        }
        scope.launch {
            val categories = outbox?.cachedList("categories", CategoryDto.serializer()) { api.fetchCategories() } ?: runCatching { api.fetchCategories() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(categories = categories)
        }
        scope.launch {
            val merchants = outbox?.cachedList("merchants", MerchantDto.serializer()) { api.fetchMerchants() } ?: runCatching { api.fetchMerchants() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(merchants = merchants)
        }
        scope.launch {
            val tags = outbox?.cachedList("tags", TagDto.serializer()) { api.fetchTags() } ?: runCatching { api.fetchTags() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(tags = tags)
        }
        scope.launch {
            val vehicles = outbox?.cachedList(OfflineCacheKeys.FLEET_VEHICLES_LIST, FleetVehicleDto.serializer()) {
                api.fetchFleetVehicles()
            } ?: runCatching { api.fetchFleetVehicles() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(
                fleetVehicles = vehicles,
                fuelLogVehicleId = _state.value.fuelLogVehicleId ?: vehicles.firstOrNull()?.id
            )
        }

        if (transactionId != null) {
            scope.launch {
                runCatching { api.fetchTransaction(transactionId) }
                    .onSuccess { detail ->
                        val fuelLog = detail.fuel_log
                        val isFuelCategory = detail.category?.name?.contains("combustible", ignoreCase = true) == true
                        val mappedLines = fuelLog?.fuel_log_lines?.map { line ->
                            FuelLogFormLineState(
                                id = line.id,
                                fuelType = line.fuel_type.ifBlank { "nafta" },
                                brand = line.brand.orEmpty(),
                                litersText = line.liters?.toString().orEmpty(),
                                costText = line.cost?.toString().orEmpty()
                            )
                        }?.takeIf { it.isNotEmpty() } ?: listOf(FuelLogFormLineState())
                        _state.value = _state.value.copy(
                            isLoading = false,
                            accountId = detail.account.id,
                            date = detail.date,
                            // detail.amount is a locale-formatted display string from the
                            // backend (Money#format, e.g. "288.000" for PYG with "." as a
                            // thousands separator) -- feeding it straight into amountText
                            // meant String.toDouble() read "288.000" as 288.0, silently
                            // mangling the value (or failing the >0 check entirely for
                            // amounts with more than one grouping separator). amount_cents
                            // is the parse-safe field the API exposes for exactly this.
                            amountText = centsToAmountText(detail.amount_cents, detail.currency),
                            nature = if (detail.classification == "income") "income" else "expense",
                            name = detail.name,
                            notes = detail.notes.orEmpty(),
                            categoryId = detail.category?.id,
                            merchantId = detail.merchant?.id,
                            selectedTagIds = detail.tags.map { it.id }.toSet(),
                            location = detail.location,
                            isFuelLogEnabled = fuelLog != null || isFuelCategory,
                            fuelLogVehicleId = fuelLog?.fleet_vehicle_id ?: _state.value.fuelLogVehicleId,
                            fuelLogOdometer = fuelLog?.odometer?.toString().orEmpty(),
                            fuelLogNotes = fuelLog?.notes.orEmpty(),
                            fuelLogLines = mappedLines,
                            existingInvoicePhoto = detail.invoice_photo,
                            invoicePhotoName = detail.invoice_photo?.filename,
                            invoicePhotoContentType = detail.invoice_photo?.content_type
                        )
                        val existingPhoto = detail.invoice_photo
                        if ((detail.has_invoice_photo || existingPhoto != null) &&
                            (existingPhoto == null || existingPhoto.content_type.startsWith("image/"))
                        ) {
                            scope.launch {
                                runCatching { api.downloadTransactionInvoicePhoto(transactionId) }
                                    .onSuccess { bytes ->
                                        _state.value = _state.value.copy(invoicePhotoBytes = bytes)
                                    }
                            }
                        }
                    }
                    .onFailure { e ->
                        val entry = runCatching { entryDao?.observeAll()?.first()?.firstOrNull { it.id == transactionId } }.getOrNull()
                        if (entry != null) {
                            val tx = runCatching { transactionDao?.findById(transactionId) }.getOrNull()
                            partialEdit = true
                            _state.value = _state.value.copy(
                                isLoading = false,
                                accountId = entry.accountId,
                                date = entry.date,
                                amountText = centsToAmountText(entry.amountCents, entry.currency),
                                nature = if (entry.amountCents > 0) "income" else "expense",
                                name = entry.name,
                                categoryId = tx?.categoryId,
                                merchantId = tx?.merchantId
                            )
                        } else {
                            _state.value = _state.value.copy(
                                isLoading = false,
                                error = e.message ?: "Error al cargar la transacción"
                            )
                        }
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
    fun updateCategoryId(value: String?) {
        val current = _state.value
        val categoryName = current.categories.firstOrNull { it.id == value }?.name.orEmpty()
        val shouldEnableFuel = current.isFuelLogEnabled || categoryName.contains("combustible", ignoreCase = true)
        _state.value = current.copy(
            categoryId = value,
            isFuelLogEnabled = shouldEnableFuel,
            fuelLogVehicleId = current.fuelLogVehicleId ?: current.fleetVehicles.firstOrNull()?.id
        )
    }
    fun updateMerchantId(value: String?) { _state.value = _state.value.copy(merchantId = value) }

    fun setCapturedLocation(latitude: Double, longitude: Double) {
        _state.value = _state.value.copy(
            capturedLatitude = latitude,
            capturedLongitude = longitude,
            location = TransactionLocationDto(
                latitude = latitude,
                longitude = longitude,
                device = _state.value.location?.device
            )
        )
    }

    fun setFuelLogEnabled(enabled: Boolean) {
        val current = _state.value
        _state.value = current.copy(
            isFuelLogEnabled = enabled,
            fuelLogVehicleId = current.fuelLogVehicleId ?: current.fleetVehicles.firstOrNull()?.id
        )
    }

    fun updateFuelLogVehicleId(value: String?) { _state.value = _state.value.copy(fuelLogVehicleId = value) }
    fun updateFuelLogOdometer(value: String) { _state.value = _state.value.copy(fuelLogOdometer = value) }
    fun updateFuelLogNotes(value: String) { _state.value = _state.value.copy(fuelLogNotes = value) }

    fun addFuelLogLine() {
        _state.value = _state.value.copy(
            fuelLogLines = _state.value.fuelLogLines + FuelLogFormLineState()
        )
    }

    fun removeFuelLogLine(index: Int) {
        val current = _state.value.fuelLogLines
        if (current.size <= 1 || index !in current.indices) return
        _state.value = _state.value.copy(
            fuelLogLines = current.filterIndexed { i, _ -> i != index }
        )
    }

    fun updateFuelLogLine(
        index: Int,
        fuelType: String? = null,
        brand: String? = null,
        litersText: String? = null,
        costText: String? = null
    ) {
        val updated = _state.value.fuelLogLines.mapIndexed { i, line ->
            if (i != index) line
            else line.copy(
                fuelType = fuelType ?: line.fuelType,
                brand = brand ?: line.brand,
                litersText = litersText ?: line.litersText,
                costText = costText ?: line.costText
            )
        }
        _state.value = _state.value.copy(fuelLogLines = updated)
    }

    fun toggleTag(id: String) {
        val current = _state.value.selectedTagIds.toMutableSet()
        if (current.contains(id)) {
            current.remove(id)
        } else {
            current.add(id)
        }
        _state.value = _state.value.copy(selectedTagIds = current)
    }

    fun selectInvoicePhoto(bytes: ByteArray, fileName: String, contentType: String) {
        _state.value = _state.value.copy(
            invoicePhotoBytes = bytes,
            invoicePhotoName = fileName,
            invoicePhotoContentType = contentType,
            hasNewInvoicePhoto = true,
            removeExistingInvoicePhoto = false
        )
    }

    fun clearInvoicePhoto() {
        val s = _state.value
        _state.value = s.copy(
            invoicePhotoBytes = null,
            invoicePhotoName = null,
            invoicePhotoContentType = null,
            hasNewInvoicePhoto = false,
            removeExistingInvoicePhoto = s.existingInvoicePhoto != null
        )
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

            var queuedBody: CreateTransactionBody? = null
            var queuedUpdate: UpdateTransactionBody? = null

            val fuelLogPayload = if (s.isFuelLogEnabled && !s.fuelLogVehicleId.isNullOrBlank()) {
                val lines = s.fuelLogLines.mapNotNull { line ->
                    val liters = line.litersText.toDoubleOrNull()
                    val cost = line.costText.toDoubleOrNull()
                    if (liters == null && cost == null) null
                    else TransactionFuelLogLineRequestDto(
                        id = line.id,
                        fuel_type = line.fuelType,
                        brand = line.brand.ifBlank { null },
                        liters = liters ?: 0.0,
                        cost = cost ?: 0.0
                    )
                }
                if (lines.isNotEmpty()) {
                    TransactionFuelLogRequestDto(
                        fleet_vehicle_id = s.fuelLogVehicleId,
                        odometer = s.fuelLogOdometer.toDoubleOrNull(),
                        notes = s.fuelLogNotes.ifBlank { null },
                        fuel_log_lines_attributes = lines
                    )
                } else null
            } else null

            val result = if (transactionId != null) {
                val body = UpdateTransactionBody(
                    account_id = s.accountId,
                    date = s.date,
                    amount = s.amountText,
                    nature = s.nature,
                    name = s.name,
                    notes = if (partialEdit) null else s.notes.ifBlank { null },
                    category_id = s.categoryId,
                    merchant_id = s.merchantId,
                    tag_ids = if (partialEdit) null else s.selectedTagIds.toList(),
                    latitude = s.capturedLatitude,
                    longitude = s.capturedLongitude,
                    fuel_log = if (partialEdit) null else fuelLogPayload
                )
                queuedUpdate = body
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
                    tag_ids = s.selectedTagIds.toList(),
                    latitude = s.capturedLatitude,
                    longitude = s.capturedLongitude,
                    fuel_log = fuelLogPayload
                )
                queuedBody = body
                runCatching { api.createTransaction(body) }
            }

            result
                .onSuccess { savedTx ->
                    if (s.hasNewInvoicePhoto && s.invoicePhotoBytes != null) {
                        runCatching {
                            api.uploadTransactionInvoicePhoto(
                                transactionId = savedTx.id,
                                fileBytes = s.invoicePhotoBytes,
                                fileName = s.invoicePhotoName ?: "factura.jpg",
                                contentType = s.invoicePhotoContentType ?: "image/jpeg"
                            )
                        }
                    } else if (s.removeExistingInvoicePhoto && transactionId != null) {
                        runCatching {
                            api.deleteTransactionInvoicePhoto(savedTx.id)
                        }
                    }
                    _state.value = _state.value.copy(isSaving = false)
                    onSaved()
                }
                .onFailure { e ->
                    val upd = queuedUpdate
                    if (upd != null && transactionId != null && outbox != null && outbox.shouldQueue(e)) {
                        outbox.enqueueTransactionUpdate(transactionId, upd, "Editar: ${upd.name}")
                        _state.value = _state.value.copy(isSaving = false)
                        onSaved()
                        return@onFailure
                    }
                    val body = queuedBody
                    if (body != null && outbox != null && outbox.shouldQueue(e)) {
                        outbox.enqueueTransaction(body, "${body.name}: ${body.amount}")
                        _state.value = _state.value.copy(isSaving = false)
                        onSaved()
                        return@onFailure
                    }
                    _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al guardar")
                }
        }
    }
}
