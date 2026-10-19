package py.com.cdco.financespy.theme

// Preferencia de variante visual por-dispositivo (Material 3 actual vs
// lenguaje de diseño iOS HIG) -- no se sincroniza con el backend ni entre
// dispositivos, solo persiste localmente para comparación lado a lado en
// runtime. Default obligatorio: MATERIAL3 (la variante actual).
enum class UiVariant(
    val id: String,
    val label: String,
    val description: String
) {
    MATERIAL3(
        id = "material3",
        label = "Material 3 (actual)",
        description = "Diseño actual con superficies glass, tarjetas flotantes y tipografía Geist."
    ),
    IOS(
        id = "ios",
        label = "iOS (HIG)",
        description = "Lenguaje visual estilo Cupertino: títulos grandes, listas agrupadas y barra inferior fija."
    );

    companion object {
        val DEFAULT: UiVariant = MATERIAL3

        fun fromId(id: String?): UiVariant =
            entries.firstOrNull { it.id == id } ?: DEFAULT
    }
}

interface UiVariantPreferences {
    fun getUiVariant(): UiVariant
    fun setUiVariant(variant: UiVariant)
}
