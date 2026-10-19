package py.com.cdco.financespy.theme

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

@RunWith(RobolectricTestRunner::class)
class AndroidUiVariantPreferencesTest {
    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        context.getSharedPreferences(AndroidUiVariantPreferences.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun defaultsToMaterial3WhenNothingPersisted() {
        val prefs = AndroidUiVariantPreferences(context)
        assertEquals(UiVariant.MATERIAL3, prefs.getUiVariant())
    }

    @Test
    fun persistsVariantAcrossPreferencesInstances() {
        val writer = AndroidUiVariantPreferences(context)
        writer.setUiVariant(UiVariant.IOS)

        val reader = AndroidUiVariantPreferences(context)
        assertEquals(UiVariant.IOS, reader.getUiVariant())

        writer.setUiVariant(UiVariant.MATERIAL3)
        assertEquals(UiVariant.MATERIAL3, AndroidUiVariantPreferences(context).getUiVariant())
    }

    @Test
    fun fallsBackToMaterial3OnCorruptedStoredValue() {
        context.getSharedPreferences(AndroidUiVariantPreferences.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(AndroidUiVariantPreferences.KEY_UI_VARIANT, "corrupted_value")
            .commit()

        val prefs = AndroidUiVariantPreferences(context)
        assertEquals(UiVariant.MATERIAL3, prefs.getUiVariant())
    }
}
