package py.com.cdco.financespy.theme

import android.content.Context

class AndroidUiVariantPreferences(context: Context) : UiVariantPreferences {
    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    override fun getUiVariant(): UiVariant {
        val raw = prefs.getString(KEY_UI_VARIANT, null)
        return UiVariant.fromId(raw)
    }

    override fun setUiVariant(variant: UiVariant) {
        prefs.edit().putString(KEY_UI_VARIANT, variant.id).apply()
    }

    companion object {
        internal const val PREFS_NAME = "financespy_ui_variant_prefs"
        internal const val KEY_UI_VARIANT = "ui_variant"
    }
}
