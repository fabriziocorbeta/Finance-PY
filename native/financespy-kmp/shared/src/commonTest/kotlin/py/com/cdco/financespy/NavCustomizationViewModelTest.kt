package py.com.cdco.financespy

import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.navigation.NavItems
import py.com.cdco.financespy.navigation.NavPreferences
import py.com.cdco.financespy.screens.NavCustomizationViewModel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private class FakeNavPreferences(initial: List<String>? = null) : NavPreferences {
    private var stored: List<String>? = initial

    override fun loadOrder(): List<String>? = stored

    override fun saveOrder(itemIds: List<String>) {
        stored = itemIds
    }
}

// FinancePyApi requiere un HttpClient real en su constructor, pero no lo usamos:
// todos los métodos relevantes están overrideados acá.
private class FakeNavApi(var remoteOrder: List<String>? = null) : FinancePyApi(io.ktor.client.HttpClient()) {
    var lastPushedOrder: List<String>? = null

    override suspend fun fetchNavItemOrder(): List<String>? = remoteOrder

    override suspend fun updateNavItemOrder(itemIds: List<String>): List<String>? {
        lastPushedOrder = itemIds
        remoteOrder = itemIds
        return itemIds
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class NavCustomizationViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @Test
    fun defaultsToCoreWebOrderWhenNothingSaved() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)

        assertEquals(NavItems.CORE_DEFAULT_ORDER, vm.uiState.value.selectedIds)
    }

    @Test
    fun toggleAddsAndRemovesItems() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)

        vm.toggle(NavItems.RULES.id)
        assertTrue(NavItems.RULES.id in vm.uiState.value.selectedIds)

        vm.toggle(NavItems.RULES.id)
        assertTrue(NavItems.RULES.id !in vm.uiState.value.selectedIds)
    }

    @Test
    fun cannotSelectMoreThanMax() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = true)

        // Ya hay 6 core seleccionados por default -> intentar agregar un 7mo no debe aplicarse.
        assertEquals(6, vm.uiState.value.selectedIds.size)
        vm.toggle(NavItems.PRODUCTS.id)
        assertEquals(6, vm.uiState.value.selectedIds.size)
        assertTrue(NavItems.PRODUCTS.id !in vm.uiState.value.selectedIds)
    }

    @Test
    fun moveUpAndDownReorderSelection() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)
        val original = vm.uiState.value.selectedIds
        val second = original[1]

        vm.moveUp(second)
        assertEquals(second, vm.uiState.value.selectedIds[0])

        vm.moveDown(second)
        assertEquals(original, vm.uiState.value.selectedIds)
    }

    @Test
    fun persistsSelectionAcrossViewModelInstances() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val vm1 = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)
        vm1.toggle(NavItems.RULES.id)
        val savedSelection = vm1.uiState.value.selectedIds

        val vm2 = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)
        assertEquals(savedSelection, vm2.uiState.value.selectedIds)
    }

    @Test
    fun resetToDefaultRestoresCoreWebOrder() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)
        vm.toggle(NavItems.DASHBOARD.id) // saca Dashboard
        assertTrue(NavItems.DASHBOARD.id !in vm.uiState.value.selectedIds)

        vm.resetToDefault()
        assertEquals(NavItems.CORE_DEFAULT_ORDER, vm.uiState.value.selectedIds)
    }

    @Test
    fun filtersOutBusinessItemsWhenBusinessModeDisabled() = testScope.runTest {
        val prefs = FakeNavPreferences(initial = NavItems.CORE_DEFAULT_ORDER + NavItems.PRODUCTS.id)
        val vm = NavCustomizationViewModel(testScope, prefs, FakeNavApi(), businessModeEnabled = false)

        assertTrue(NavItems.PRODUCTS.id !in vm.uiState.value.selectedIds)
    }

    @Test
    fun syncsSelectionFromServerOnInit() = testScope.runTest {
        val prefs = FakeNavPreferences(initial = NavItems.CORE_DEFAULT_ORDER)
        val remoteOrder = listOf(NavItems.RULES.id, NavItems.DASHBOARD.id)
        val api = FakeNavApi(remoteOrder = remoteOrder)
        val vm = NavCustomizationViewModel(testScope, prefs, api, businessModeEnabled = false)

        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(remoteOrder, vm.uiState.value.selectedIds)
        assertEquals(remoteOrder, prefs.loadOrder())
    }

    @Test
    fun pushesChangesToServerOnToggle() = testScope.runTest {
        val prefs = FakeNavPreferences()
        val api = FakeNavApi()
        val vm = NavCustomizationViewModel(testScope, prefs, api, businessModeEnabled = false)

        vm.toggle(NavItems.RULES.id)
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(vm.uiState.value.selectedIds, api.lastPushedOrder)
    }
}
