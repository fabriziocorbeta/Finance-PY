package py.com.cdco.financespy.theme

import kotlin.test.Test
import kotlin.test.assertEquals

private class FakeUiVariantPreferences(
    initial: UiVariant = UiVariant.DEFAULT
) : UiVariantPreferences {
    private var stored: UiVariant = initial

    override fun getUiVariant(): UiVariant = stored

    override fun setUiVariant(variant: UiVariant) {
        stored = variant
    }
}

class UiVariantPreferencesTest {
    @Test
    fun defaultVariantIsMaterial3() {
        assertEquals(UiVariant.MATERIAL3, UiVariant.DEFAULT)
        val prefs = FakeUiVariantPreferences()
        assertEquals(UiVariant.MATERIAL3, prefs.getUiVariant())
    }

    @Test
    fun fromIdResolvesKnownIdsAndFallsBackToDefault() {
        assertEquals(UiVariant.MATERIAL3, UiVariant.fromId("material3"))
        assertEquals(UiVariant.IOS, UiVariant.fromId("ios"))
        assertEquals(UiVariant.MATERIAL3, UiVariant.fromId(null))
        assertEquals(UiVariant.MATERIAL3, UiVariant.fromId(""))
        assertEquals(UiVariant.MATERIAL3, UiVariant.fromId("unknown_variant"))
    }

    @Test
    fun setUiVariantPersistsNewSelection() {
        val prefs = FakeUiVariantPreferences()
        assertEquals(UiVariant.MATERIAL3, prefs.getUiVariant())

        prefs.setUiVariant(UiVariant.IOS)
        assertEquals(UiVariant.IOS, prefs.getUiVariant())

        prefs.setUiVariant(UiVariant.MATERIAL3)
        assertEquals(UiVariant.MATERIAL3, prefs.getUiVariant())
    }
}
