package py.com.cdco.financespy.cache

// Cache del último DashboardDto recibido, por período (o "default" si no hay
// período seleccionado) -- permite mostrar datos al instante al abrir la app
// mientras se refresca en background, en vez de arrancar en null/loading
// cada vez. Guarda el JSON crudo tal cual lo devuelve el backend: replicar
// esa lógica (sankey, donut, balance sheet) client-side sería duplicar
// reglas de negocio del server, así que no se reconstruye nada localmente.
interface DashboardCache {
    fun load(periodKey: String?): String?
    fun save(periodKey: String?, json: String)
}
