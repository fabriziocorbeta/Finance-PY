package py.com.cdco.financespy.sync

import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

object OfflineCacheKeys {
    const val PRODUCTS_LIST = "cache_products_list"
    const val SALES_LIST = "cache_sales_list"
    const val PURCHASE_ORDERS_LIST = "cache_purchase_orders_list"
    const val FLEET_VEHICLES_LIST = "cache_fleet_vehicles_list"
    const val CHATS_LIST = "cache_chats_list"
    const val HOLDINGS_LIST = "cache_holdings_list"
    const val ACCOUNTS_LIST = "cache_accounts_list"
    const val DASHBOARD_DTO = "cache_dashboard_dto"
    const val FAMILY_SETTINGS = "cache_family_settings"

    fun saleDetail(id: String) = "cache_sale_detail_$id"
    fun purchaseOrderDetail(id: String) = "cache_purchase_order_detail_$id"
    fun fleetVehicleDetail(id: String) = "cache_fleet_vehicle_detail_$id"
    fun chatDetail(id: String) = "cache_chat_detail_$id"
    fun budget(param: String) = "cache_budget_$param"
    fun securityPrices(securityId: String) = "cache_security_prices_$securityId"
}

class OfflineCache(private val store: OfflineStore?) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    fun <T> get(key: String, serializer: KSerializer<T>): T? {
        val raw = store?.get(key) ?: return null
        return runCatching { json.decodeFromString(serializer, raw) }.getOrNull()
    }

    fun <T> put(key: String, serializer: KSerializer<T>, value: T) {
        val storeRef = store ?: return
        runCatching {
            storeRef.put(key, json.encodeToString(serializer, value))
        }
    }

    fun <T> getList(key: String, elementSerializer: KSerializer<T>): List<T>? =
        get(key, ListSerializer(elementSerializer))

    fun <T> putList(key: String, elementSerializer: KSerializer<T>, value: List<T>) =
        put(key, ListSerializer(elementSerializer), value)

    /** Rewrites a cached list in place (optimistic local edits made while offline). */
    fun <T> updateList(key: String, elementSerializer: KSerializer<T>, transform: (List<T>) -> List<T>) {
        val current = getList(key, elementSerializer) ?: return
        putList(key, elementSerializer, transform(current))
    }

    fun remove(key: String) {
        runCatching { store?.remove(key) }
    }
}
