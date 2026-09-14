package py.com.cdco.financespy

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

class NavCustomizationViewModelTest {

    @Test
    fun defaultsToCoreWebOrderWhenNothingSaved() {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(prefs, businessModeEnabled = false)

        assertEquals(NavItems.CORE_DEFAULT_ORDER, vm.uiState.value.selectedIds)
    }

    @Test
    fun toggleAddsAndRemovesItems() {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(prefs, businessModeEnabled = false)

        vm.toggle(NavItems.RULES.id)
        assertTrue(NavItems.RULES.id in vm.uiState.value.selectedIds)

        vm.toggle(NavItems.RULES.id)
        assertTrue(NavItems.RULES.id !in vm.uiState.value.selectedIds)
    }

    @Test
    fun cannotSelectMoreThanMax() {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(prefs, businessModeEnabled = true)

        // Ya hay 6 core seleccionados por default -> intentar agregar un 7mo no debe aplicarse.
        assertEquals(6, vm.uiState.value.selectedIds.size)
        vm.toggle(NavItems.PRODUCTS.id)
        assertEquals(6, vm.uiState.value.selectedIds.size)
        assertTrue(NavItems.PRODUCTS.id !in vm.uiState.value.selectedIds)
    }

    @Test
    fun moveUpAndDownReorderSelection() {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(prefs, businessModeEnabled = false)
        val original = vm.uiState.value.selectedIds
        val second = original[1]

        vm.moveUp(second)
        assertEquals(second, vm.uiState.value.selectedIds[0])

        vm.moveDown(second)
        assertEquals(original, vm.uiState.value.selectedIds)
    }

    @Test
    fun persistsSelectionAcrossViewModelInstances() {
        val prefs = FakeNavPreferences()
        val vm1 = NavCustomizationViewModel(prefs, businessModeEnabled = false)
        vm1.toggle(NavItems.RULES.id)
        val savedSelection = vm1.uiState.value.selectedIds

        val vm2 = NavCustomizationViewModel(prefs, businessModeEnabled = false)
        assertEquals(savedSelection, vm2.uiState.value.selectedIds)
    }

    @Test
    fun resetToDefaultRestoresCoreWebOrder() {
        val prefs = FakeNavPreferences()
        val vm = NavCustomizationViewModel(prefs, businessModeEnabled = false)
        vm.toggle(NavItems.DASHBOARD.id) // saca Dashboard
        assertTrue(NavItems.DASHBOARD.id !in vm.uiState.value.selectedIds)

        vm.resetToDefault()
        assertEquals(NavItems.CORE_DEFAULT_ORDER, vm.uiState.value.selectedIds)
    }

    @Test
    fun filtersOutBusinessItemsWhenBusinessModeDisabled() {
        val prefs = FakeNavPreferences(initial = NavItems.CORE_DEFAULT_ORDER + NavItems.PRODUCTS.id)
        val vm = NavCustomizationViewModel(prefs, businessModeEnabled = false)

        assertTrue(NavItems.PRODUCTS.id !in vm.uiState.value.selectedIds)
    }
}
