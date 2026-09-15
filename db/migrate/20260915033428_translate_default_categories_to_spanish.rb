class TranslateDefaultCategoriesToSpanish < ActiveRecord::Migration[7.2]
  # Category#default_categories generaba las 21 categorías default en
  # inglés fijo, sin importar la locale de la family -- reportado por
  # Fabrizio con captura (Healthcare/Home Improvement/Loan Payments/etc
  # en la lista de una family en es-PY). El código ya está arreglado
  # (usa I18n.t) para familias NUEVAS; esta migración traduce las
  # categorías default ya sembradas en families existentes.
  #
  # Solo renombra si name+color+icon coinciden EXACTO con el default
  # original en inglés -- si el usuario ya renombró/recoloreó/cambió el
  # ícono de una categoría default, deja de matchear y no se toca.
  # `categories` tiene FORCE ROW LEVEL SECURITY, así que itera por
  # family con RlsContext.set_family (mismo patrón, y mismo error a
  # evitar, que la migración de Sale de esta misma sesión).
  DEFAULTS = [
    [ "Income", "Ingresos", "#22c55e", "circle-dollar-sign" ],
    [ "Food & Drink", "Comidas y bebidas", "#f97316", "utensils" ],
    [ "Groceries", "Almacén", "#407706", "shopping-bag" ],
    [ "Shopping", "Compras", "#3b82f6", "shopping-cart" ],
    [ "Transportation", "Transporte", "#0ea5e9", "bus" ],
    [ "Travel", "Viajes", "#2563eb", "plane" ],
    [ "Entertainment", "Entretenimiento", "#a855f7", "drama" ],
    [ "Healthcare", "Salud", "#4da568", "pill" ],
    [ "Personal Care", "Cuidado personal", "#14b8a6", "scissors" ],
    [ "Home Improvement", "Mejoras del hogar", "#d97706", "hammer" ],
    [ "Mortgage / Rent", "Hipoteca / Alquiler", "#b45309", "home" ],
    [ "Utilities", "Servicios básicos", "#eab308", "lightbulb" ],
    [ "Subscriptions", "Suscripciones", "#6366f1", "wifi" ],
    [ "Insurance", "Seguros", "#0284c7", "shield" ],
    [ "Sports & Fitness", "Deportes y fitness", "#10b981", "dumbbell" ],
    [ "Gifts & Donations", "Regalos y donaciones", "#61c9ea", "hand-helping" ],
    [ "Taxes", "Impuestos", "#dc2626", "landmark" ],
    [ "Loan Payments", "Pago de préstamos", "#e11d48", "credit-card" ],
    [ "Services", "Servicios", "#7c3aed", "briefcase" ],
    [ "Fees", "Comisiones", "#6b7280", "receipt" ],
    [ "Savings & Investments", "Ahorros e inversiones", "#059669", "piggy-bank" ]
  ].freeze

  def up
    Family.find_each do |family|
      RlsContext.set_family(family)

      DEFAULTS.each do |english_name, spanish_name, color, icon|
        family.categories
          .where(name: english_name, color: color, lucide_icon: icon)
          .update_all(name: spanish_name)
      end
    end
  end

  def down
    Family.find_each do |family|
      RlsContext.set_family(family)

      DEFAULTS.each do |english_name, spanish_name, color, icon|
        family.categories
          .where(name: spanish_name, color: color, lucide_icon: icon)
          .update_all(name: english_name)
      end
    end
  end
end
