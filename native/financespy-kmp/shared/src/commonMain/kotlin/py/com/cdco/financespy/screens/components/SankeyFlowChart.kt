package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import py.com.cdco.financespy.api.dto.CashflowSankeyDto
import py.com.cdco.financespy.api.dto.SankeyLinkDto
import py.com.cdco.financespy.api.dto.SankeyNodeDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

fun parseColorString(
    colorStr: String?,
    defaultColor: Color,
    successColor: Color,
    destructiveColor: Color,
    warningColor: Color,
    primaryColor: Color
): Color {
    if (colorStr.isNullOrBlank()) return defaultColor
    return when {
        colorStr.contains("success") -> successColor
        colorStr.contains("destructive") -> destructiveColor
        colorStr.contains("warning") -> warningColor
        colorStr.contains("primary") -> primaryColor
        colorStr.startsWith("#") -> parseHexColor(colorStr)
        else -> defaultColor
    }
}

internal data class NodeLayout(
    val nodeIdx: Int,
    val layer: Int,
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
    val centerY: Float
)

internal data class SankeyLayerInfo(
    val centerIdx: Int,
    val centerLayer: Int,
    val maxLayer: Int,
    val layerMap: Map<Int, Int>
)

// Comparte la asignación de nodos a columnas (capas) entre el cálculo de
// altura del chart y el layout real -- antes vivía solo adentro de
// SankeyCanvasLayout, así que el alto fijo de 280dp no tenía forma de saber
// cuántos nodos iban a caer en la columna más cargada, y con 5+ categorías
// de gasto las labels terminaban pisándose entre sí.
internal fun computeSankeyLayers(sankeyDto: CashflowSankeyDto): SankeyLayerInfo {
    val nodes = sankeyDto.nodes
    val links = sankeyDto.links

    val centerIdx = nodes.indexOfFirst {
        it.name.contains("Flujo de caja", ignoreCase = true)
    }.let { if (it >= 0) it else 0 }

    val incomingMap = mutableMapOf<Int, MutableList<SankeyLinkDto>>()
    val outgoingMap = mutableMapOf<Int, MutableList<SankeyLinkDto>>()

    links.forEach { link ->
        incomingMap.getOrPut(link.target) { mutableListOf() }.add(link)
        outgoingMap.getOrPut(link.source) { mutableListOf() }.add(link)
    }

    val hasIncomeSubs = nodes.indices.any { i ->
        i != centerIdx &&
        outgoingMap[i]?.any { it.target == centerIdx } == true &&
        incomingMap[i]?.isNotEmpty() == true
    }

    val centerLayer = if (hasIncomeSubs) 2 else 1

    val hasExpenseSubs = nodes.indices.any { j ->
        j != centerIdx &&
        incomingMap[j]?.any { it.source == centerIdx } == true &&
        outgoingMap[j]?.isNotEmpty() == true
    }

    val maxLayer = centerLayer + (if (hasExpenseSubs) 2 else 1)

    val layerMap = mutableMapOf<Int, Int>()
    layerMap[centerIdx] = centerLayer

    nodes.indices.forEach { idx ->
        if (idx == centerIdx) return@forEach

        val isIncome = outgoingMap[idx]?.any { l -> l.target == centerIdx || (layerMap[l.target] != null && layerMap[l.target]!! <= centerLayer) } == true ||
                       incomingMap[idx]?.any { l -> layerMap[l.source] != null && layerMap[l.source]!! < centerLayer } == true

        if (isIncome) {
            val hasIncoming = incomingMap[idx]?.isNotEmpty() == true
            // d3-sankey real usa nodeAlign "justify" (el default): TODO
            // nodo sin incoming edges va a la columna 0, sin importar
            // cuántos saltos tenga hasta el centro -- confirmado
            // inspeccionando el SVG real de la web (Salario, sin
            // subcategorías, queda en la MISMA columna x que "Venta de
            // Mercaderías", no con "Negocio"). El cruce en pico que un
            // fix anterior "corrigió" moviendo a Salario a la columna de
            // Negocio era en realidad comportamiento correcto de la web,
            // no un bug -- se revierte a la regla real: solo el nodo
            // agregador (con incoming) va a la columna adyacente al
            // centro, cualquier nodo sin incoming va a la columna 0.
            if (hasIncomeSubs) {
                layerMap[idx] = if (hasIncoming) 1 else 0
            } else {
                layerMap[idx] = 0
            }
        } else {
            val hasOutgoing = outgoingMap[idx]?.isNotEmpty() == true
            if (hasExpenseSubs) {
                layerMap[idx] = if (hasOutgoing) centerLayer + 1 else maxLayer
            } else {
                layerMap[idx] = centerLayer + 1
            }
        }
    }

    return SankeyLayerInfo(centerIdx = centerIdx, centerLayer = centerLayer, maxLayer = maxLayer, layerMap = layerMap)
}

// Cantidad de nodos en la columna más cargada (sin contar el nodo central,
// que siempre ocupa una sola fila) -- usada para dimensionar el alto del
// chart dinámicamente en vez de un 280dp fijo.
internal fun maxNodesInAnyLayer(sankeyDto: CashflowSankeyDto): Int {
    if (sankeyDto.nodes.isEmpty()) return 0
    val info = computeSankeyLayers(sankeyDto)
    return sankeyDto.nodes.indices
        .filter { it != info.centerIdx }
        .groupingBy { info.layerMap[it] ?: info.centerLayer }
        .eachCount()
        .values
        .maxOrNull() ?: 1
}

// Ajustar altura/modo-compacto sigue teniendo un techo: con 7-8+ categorías
// reales en una columna (visto en prod: familias con varias categorías de
// gasto activas) no hay combinación de alto dinámico ni ancho de columna que
// entre cómodo en una pantalla de teléfono sin scroll horizontal, que este
// chart no soporta. En vez de perseguir constantes cada vez que aparece una
// family con más categorías, se acota cada columna a máximo `maxPerLayer`
// nodos reales, agrupando el resto (los de menor valor) en un nodo "Otros"
// -- balancea la vista del negocio sin importar cuántas categorías tenga la
// family, en vez de romperse de nuevo con la próxima que tenga 9.
internal fun capNodesPerLayer(sankeyDto: CashflowSankeyDto, maxPerLayer: Int = 6): CashflowSankeyDto {
    if (sankeyDto.nodes.size <= maxPerLayer + 1) return sankeyDto

    val info = computeSankeyLayers(sankeyDto)
    val byLayer = sankeyDto.nodes.indices
        .filter { it != info.centerIdx }
        .groupBy { info.layerMap[it] ?: info.centerLayer }

    val keepIndices = mutableSetOf(info.centerIdx)
    val mergeGroups = mutableMapOf<Int, List<Int>>()

    byLayer.forEach { (layer, indices) ->
        if (indices.size <= maxPerLayer) {
            keepIndices.addAll(indices)
        } else {
            val sorted = indices.sortedByDescending { sankeyDto.nodes[it].value }
            keepIndices.addAll(sorted.take(maxPerLayer - 1))
            mergeGroups[layer] = sorted.drop(maxPerLayer - 1)
        }
    }

    if (mergeGroups.isEmpty()) return sankeyDto

    val newNodes = mutableListOf<SankeyNodeDto>()
    val oldToNew = mutableMapOf<Int, Int>()
    sankeyDto.nodes.indices.forEach { idx ->
        if (idx in keepIndices) {
            oldToNew[idx] = newNodes.size
            newNodes.add(sankeyDto.nodes[idx])
        }
    }

    mergeGroups.forEach { (_, indices) ->
        val totalValue = indices.sumOf { sankeyDto.nodes[it].value }
        val otrosIdx = newNodes.size
        newNodes.add(SankeyNodeDto(name = "Otros", value = totalValue, color = sankeyDto.nodes[indices.first()].color))
        indices.forEach { oldToNew[it] = otrosIdx }
    }

    val linkAgg = linkedMapOf<Pair<Int, Int>, Double>()
    val linkColor = mutableMapOf<Pair<Int, Int>, String?>()
    sankeyDto.links.forEach { link ->
        val newSource = oldToNew[link.source] ?: return@forEach
        val newTarget = oldToNew[link.target] ?: return@forEach
        if (newSource == newTarget) return@forEach
        val key = newSource to newTarget
        linkAgg[key] = (linkAgg[key] ?: 0.0) + link.value
        linkColor.putIfAbsent(key, link.color)
    }

    val newLinks = linkAgg.map { (key, value) ->
        SankeyLinkDto(source = key.first, target = key.second, value = value, color = linkColor[key])
    }

    return sankeyDto.copy(nodes = newNodes, links = newLinks)
}

// Ancho (en px) que necesita cada columna para mostrar su texto sin
// truncar, más el de la columna central. Reemplaza el reparto uniforme
// de ancho entre columnas (colSpacing) que nunca convergía con 4 columnas
// -- acá cada columna recibe exactamente lo que su contenido más largo
// necesita, medido de verdad con el TextMeasurer, en vez de adivinar una
// constante en dp y recortar lo que no entra.
internal data class ColumnWidths(
    val labelWidthPx: Map<Int, Float>,
    val centerLabelWidthPx: Float
)

private const val MIN_LABEL_WIDTH_DP = 40

internal fun computeColumnWidths(
    sankeyDto: CashflowSankeyDto,
    layerInfo: SankeyLayerInfo,
    currency: String,
    textMeasurer: TextMeasurer,
    labelSmallStyle: TextStyle,
    bodySmallStyle: TextStyle,
    density: Density
): ColumnWidths {
    val nodes = sankeyDto.nodes
    val nodesByLayer = nodes.indices.groupBy { layerInfo.layerMap[it] ?: layerInfo.centerLayer }
    val minPx = with(density) { MIN_LABEL_WIDTH_DP.dp.toPx() }
    // SankeyNodeLabel antepone un punto de color (6dp) + spacer (4dp) al
    // texto en columnas no centrales -- si no se reserva ese ancho acá, el
    // Text termina con 10dp menos de lo medido y trunca.
    val dotAndSpacerPx = with(density) { 10.dp.toPx() }

    // Sin tope de ancho ni abreviación: la web (d3-sankey) muestra los
    // nombres siempre completos, tolerando que las columnas vecinas se
    // acerquen o el texto se superponga visualmente antes que cortar
    // información -- reproducir ese comportamiento acá en vez de abreviar.
    fun measureNodeWidth(idx: Int, reserveDotWidth: Boolean): Float {
        val nameW = textMeasurer.measure(nodes[idx].name, labelSmallStyle).size.width.toFloat()
        val valW = textMeasurer.measure(formatMoney(nodes[idx].value, currency), bodySmallStyle).size.width.toFloat()
        val reserve = if (reserveDotWidth) dotAndSpacerPx else 0f
        return maxOf(nameW, valW) + reserve
    }

    val labelWidthPx = mutableMapOf<Int, Float>()
    (0..layerInfo.maxLayer).forEach { layer ->
        if (layer == layerInfo.centerLayer) return@forEach
        val indices = nodesByLayer[layer] ?: emptyList()
        val maxW = indices.maxOfOrNull { measureNodeWidth(it, reserveDotWidth = true) } ?: minPx
        labelWidthPx[layer] = maxW.coerceAtLeast(minPx)
    }

    val centerW = measureNodeWidth(layerInfo.centerIdx, reserveDotWidth = false).coerceAtLeast(minPx)

    return ColumnWidths(labelWidthPx = labelWidthPx, centerLabelWidthPx = centerW)
}

@Composable
fun SankeyFlowChart(
    sankeyDto: CashflowSankeyDto?,
    currency: String = "PYG",
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Flujo de caja",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )

            val nodes = sankeyDto?.nodes ?: emptyList()
            val links = sankeyDto?.links ?: emptyList()

            if (nodes.isEmpty() || links.isEmpty()) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "No hay datos de flujo de caja para este período",
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textPrimary()
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "Añade transacciones para mostrar datos de flujo de caja o amplía el período de tiempo",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            } else {
                Spacer(modifier = Modifier.height(16.dp))
                // Capar nodos por columna (ver capNodesPerLayer) antes que
                // nada más -- con muchas categorías reales no hay alto ni
                // ancho que alcance en una pantalla de teléfono sin agrupar
                // las de menor valor en "Otros". Alto todavía se calcula
                // dinámico sobre el dataset YA acotado (máx. 6 nodos reales
                // por columna, así que el piso de 280dp cubre casi siempre).
                // 56dp/nodo: cada label es siempre 2 líneas (nombre + monto),
                // sin modo compacto -- ver comentario de isCompact más abajo.
                val cappedDto = remember(sankeyDto) { capNodesPerLayer(sankeyDto!!) }
                val maxNodesInColumn = maxNodesInAnyLayer(cappedDto)
                // 48dp/nodo (antes 56dp): con la fuente del Sankey reducida a
                // 10sp cada label 2-líneas ocupa menos alto real.
                val chartHeight = maxOf(280.dp, (maxNodesInColumn * 48).dp)

                // 10mo intento -- pedido explícito de duplicar el layout de
                // la web (d3-sankey): columnas repartidas parejo en el ancho
                // fijo de pantalla (como el .extent() de d3), nunca creciendo
                // por el contenido. Las etiquetas se dibujan sueltas al lado
                // de cada barra sin caja que las recorte (overflow=Visible
                // en SankeyNodeLabel) -- si dos columnas quedan cerca el
                // texto se puede superponer, igual que en la web, pero
                // siempre entra todo en una sola pantalla sin scroll.
                val layerInfo = remember(cappedDto) { computeSankeyLayers(cappedDto) }
                val textMeasurer = rememberTextMeasurer()
                // Fuente propia del Sankey, mas chica que labelSmall/bodySmall
                // del resto de la app (~11-12sp) -- la web muestra nombres
                // largos ('Venta de Mercaderias', 'Pago de prestamos') en una
                // sola linea sin wrap, y a 4 columnas en un telefono real eso
                // no entra con el tamano de fuente estandar sin importar
                // cuanto se recorten margenes/gaps.
                val labelSmallStyle = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, lineHeight = 12.sp)
                val bodySmallStyle = MaterialTheme.typography.bodySmall.copy(fontSize = 10.sp, lineHeight = 12.sp)
                val density = LocalDensity.current
                val columnWidths = remember(cappedDto, layerInfo, currency, labelSmallStyle, bodySmallStyle, density) {
                    computeColumnWidths(cappedDto, layerInfo, currency, textMeasurer, labelSmallStyle, bodySmallStyle, density)
                }

                SankeyCanvasLayout(
                    sankeyDto = cappedDto,
                    currency = currency,
                    layerInfo = layerInfo,
                    columnWidths = columnWidths,
                    modifier = Modifier.fillMaxWidth().height(chartHeight)
                )
            }
        }
    }
}

@Composable
private fun SankeyCanvasLayout(
    sankeyDto: CashflowSankeyDto,
    currency: String,
    layerInfo: SankeyLayerInfo,
    columnWidths: ColumnWidths,
    modifier: Modifier = Modifier
) {
    val nodes = sankeyDto.nodes
    val links = sankeyDto.links

    val successColor = FinancePyColors.success()
    val destructiveColor = FinancePyColors.destructive()
    val warningColor = FinancePyColors.warning()
    val primaryColor = FinancePyColors.buttonBgPrimary()
    val textSecondaryColor = FinancePyColors.textSecondary()
    val defaultColor = FinancePyColors.textSecondary()

    val centerIdx = layerInfo.centerIdx
    val centerLayer = layerInfo.centerLayer
    val maxLayer = layerInfo.maxLayer
    val layerMap = layerInfo.layerMap

    val incomingMap = mutableMapOf<Int, MutableList<SankeyLinkDto>>()
    val outgoingMap = mutableMapOf<Int, MutableList<SankeyLinkDto>>()

    links.forEach { link ->
        incomingMap.getOrPut(link.target) { mutableListOf() }.add(link)
        outgoingMap.getOrPut(link.source) { mutableListOf() }.add(link)
    }

    val density = LocalDensity.current

    BoxWithConstraints(modifier = modifier) {
        val widthPx = constraints.maxWidth.toFloat()
        val heightPx = constraints.maxHeight.toFloat()

        val barWidth = with(density) { 8.dp.toPx() }
        val edgeMargin = with(density) { 10.dp.toPx() }
        val barLabelGap = with(density) { 2.dp.toPx() }
        val minLabelW = with(density) { MIN_LABEL_WIDTH_DP.dp.toPx() }

        // Columnas repartidas parejo en el ancho fijo disponible -- igual
        // que d3-sankey con un .extent() fijo: la posición de cada capa
        // depende solo de su profundidad, nunca del ancho del texto que
        // muestra. Con solo 1 profundidad (maxLayer=0) todo va a
        // edgeMargin.
        val totalDepths = maxLayer + 1
        val usableWidth = (widthPx - 2 * edgeMargin - barWidth).coerceAtLeast(barWidth)
        val depthStep = if (totalDepths > 1) usableWidth / (totalDepths - 1) else 0f

        val barXByLayer = (0..maxLayer).associateWith { layer -> edgeMargin + layer * depthStep }

        // Ancho "nominal" de la etiqueta por columna, solo para saber dónde
        // arrancar/terminar su caja -- no recorta el texto (SankeyNodeLabel
        // usa overflow=Visible), así que un nombre largo puede pintar más
        // allá de este ancho hacia la columna vecina, igual que en la web.
        val nominalLabelW = (depthStep - barWidth - 2 * barLabelGap).coerceAtLeast(minLabelW)

        val labelBoxByLayer = mutableMapOf<Int, Pair<Float, Float>>()
        (0..maxLayer).forEach { layer ->
            if (layer == centerLayer) return@forEach
            val barX = barXByLayer[layer] ?: edgeMargin
            if (layer < centerLayer) {
                labelBoxByLayer[layer] = (barX + barWidth + barLabelGap) to nominalLabelW
            } else {
                labelBoxByLayer[layer] = (barX - barLabelGap - nominalLabelW) to nominalLabelW
            }
        }
        labelBoxByLayer[centerLayer] = run {
            val barX = barXByLayer[centerLayer] ?: edgeMargin
            val centerW = columnWidths.centerLabelWidthPx
            (barX + barWidth / 2f - centerW / 2f) to centerW
        }

        val nodesByLayer = nodes.indices.groupBy { layerMap[it] ?: centerLayer }
        val nodeLayouts = mutableMapOf<Int, NodeLayout>()
        val verticalMargin = with(density) { 20.dp.toPx() }
        val gapPx = with(density) { 12.dp.toPx() }

        (0..maxLayer).forEach { layer ->
            val colNodeIndices = nodesByLayer[layer] ?: emptyList()
            if (colNodeIndices.isEmpty()) return@forEach

            val colX = barXByLayer[layer] ?: edgeMargin
            val colTotalVal = colNodeIndices.sumOf { nodes[it].value }.let { if (it <= 0) 1.0 else it }
            val gap = if (colNodeIndices.size > 1) gapPx else 0f
            val availableH = (heightPx - 2 * verticalMargin - (colNodeIndices.size - 1) * gap).coerceAtLeast(20f)

            var currentY = verticalMargin
            colNodeIndices.forEach { nodeIdx ->
                val node = nodes[nodeIdx]
                val nodeH = if (nodeIdx == centerIdx) {
                    (heightPx * 0.32f).coerceAtLeast(36f)
                } else {
                    ((node.value / colTotalVal) * availableH).toFloat().coerceAtLeast(8f)
                }

                // "Flujo de caja" es columna de un solo nodo -- centrarlo
                // en el alto total en vez de heredar el mismo anclaje
                // arriba que usan las columnas apiladas.
                val nodeY = if (nodeIdx == centerIdx) (heightPx - nodeH) / 2f else currentY

                val nodeLayout = NodeLayout(
                    nodeIdx = nodeIdx,
                    layer = layer,
                    x = colX,
                    y = nodeY,
                    width = barWidth,
                    height = nodeH,
                    centerY = nodeY + nodeH / 2f
                )
                nodeLayouts[nodeIdx] = nodeLayout
                currentY += nodeH + gap
            }
        }

        Canvas(modifier = Modifier.fillMaxSize()) {
            nodeLayouts.values.forEach { layout ->
                val node = nodes[layout.nodeIdx]
                val nodeColor = parseColorString(
                    node.color, defaultColor, successColor, destructiveColor, warningColor, primaryColor
                )
                drawRoundRect(
                    color = nodeColor,
                    topLeft = Offset(layout.x, layout.y),
                    size = Size(layout.width, layout.height),
                    cornerRadius = CornerRadius(4f, 4f)
                )
            }

            // Dibuja primero los hilos que saltan varias columnas (ej.
            // "Salario" directo a "Flujo de caja", sin pasar por
            // "Negocio") para que queden detrás de los hilos cortos entre
            // columnas vecinas -- si no, el cruce entre un hilo largo y
            // uno corto arma un pico filoso en vez de leerse como dos
            // capas separadas, igual que pasa en la web con el z-order de
            // los links.
            val orderedLinks = links.sortedByDescending { link ->
                val srcLayer = layerMap[link.source] ?: centerLayer
                val dstLayer = layerMap[link.target] ?: centerLayer
                kotlin.math.abs(dstLayer - srcLayer)
            }

            orderedLinks.forEach { link ->
                val srcLayout = nodeLayouts[link.source] ?: return@forEach
                val dstLayout = nodeLayouts[link.target] ?: return@forEach

                // Replica exacta de sankey_chart_controller.js#drawLinks:
                // NO es una banda rellena (d3.sankeyLinkHorizontal) -- es
                // un trazo (stroke) centrado, ancho = max(1, d.width), con
                // un gradiente lineal horizontal del color del nodo
                // origen al color del nodo destino, ambos a opacidad 0.1.
                // Cada link se posiciona en el CENTRO de su porción
                // dentro del stack del nodo (no como banda con bordes
                // propios).
                val outgoingLinksForSrc = outgoingMap[link.source] ?: emptyList()
                val incomingLinksForDst = incomingMap[link.target] ?: emptyList()

                val srcIdx = outgoingLinksForSrc.indexOfFirst { it === link }.coerceAtLeast(0)
                val dstIdx = incomingLinksForDst.indexOfFirst { it === link }.coerceAtLeast(0)

                val srcTotal = outgoingLinksForSrc.sumOf { it.value }.let { if (it <= 0.0) 1.0 else it }
                val dstTotal = incomingLinksForDst.sumOf { it.value }.let { if (it <= 0.0) 1.0 else it }

                val srcOffset = outgoingLinksForSrc.take(srcIdx).sumOf { it.value }
                val dstOffset = incomingLinksForDst.take(dstIdx).sumOf { it.value }

                // La web (stroke-width: Math.max(1, d.width)) no tiene
                // tope artificial -- con la escala global ya realista
                // (globalKy) el grosor sale proporcionalmente correcto
                // solo, este tope queda como red de seguridad, no como
                // el límite real de diseño.
                val maxThickness = with(density) { 32.dp.toPx() }

                val srcThickness = (link.value / srcTotal * srcLayout.height).toFloat()
                    .coerceIn(1.5f, maxThickness)
                val srcY = srcLayout.y + ((srcOffset + link.value / 2.0) / srcTotal * srcLayout.height).toFloat()

                val dstThickness = (link.value / dstTotal * dstLayout.height).toFloat()
                    .coerceIn(1.5f, maxThickness)
                val dstY = dstLayout.y + ((dstOffset + link.value / 2.0) / dstTotal * dstLayout.height).toFloat()

                val strokeWidth = maxOf(srcThickness, dstThickness).coerceAtLeast(with(density) { 1.dp.toPx() })

                val startX = srcLayout.x + barWidth
                val endX = dstLayout.x
                val dx = (endX - startX).coerceAtLeast(4f)
                val cx = dx * 0.5f

                val path = Path().apply {
                    moveTo(startX, srcY)
                    cubicTo(startX + cx, srcY, startX + cx, dstY, endX, dstY)
                }

                val srcNodeColor = parseColorString(
                    nodes[link.source].color, defaultColor, successColor, destructiveColor, warningColor, primaryColor
                )
                val dstNodeColor = parseColorString(
                    nodes[link.target].color, defaultColor, successColor, destructiveColor, warningColor, primaryColor
                )
                val gradientBrush = Brush.linearGradient(
                    colors = listOf(srcNodeColor.copy(alpha = 0.1f), dstNodeColor.copy(alpha = 0.1f)),
                    start = Offset(startX, 0f),
                    end = Offset(endX, 0f)
                )

                drawPath(path = path, brush = gradientBrush, style = Stroke(width = strokeWidth))
            }
        }

        val textMeasurer = rememberTextMeasurer()
        // Misma fuente reducida que en SankeyFlowChart (10sp) -- tiene que
        // coincidir para que el alto medido acá corresponda al ancho medido
        // allá.
        val labelSmallStyle = MaterialTheme.typography.labelSmall.copy(fontSize = 10.sp, lineHeight = 12.sp)
        val bodySmallStyle = MaterialTheme.typography.bodySmall.copy(fontSize = 10.sp, lineHeight = 12.sp)

        // Modo compacto (concatenar "nombre • monto" en una sola línea)
        // eliminado -- pedía más ancho horizontal justo en las columnas que
        // menos tenían. Con el ancho ahora medido por columna (ver
        // ColumnWidths más arriba) cada label ya tiene el ancho exacto que
        // necesita en 2 líneas, así que siempre se usa ese modo.
        val nodeLabelHeightsPx = nodes.indices.associateWith { idx ->
            val node = nodes[idx]
            val titleH = textMeasurer.measure(node.name, labelSmallStyle).size.height
            val valH = textMeasurer.measure(formatMoney(node.value, currency), bodySmallStyle).size.height
            (titleH + valH).toFloat()
        }

        // Ancho REAL renderizado (no el nominal de columna) -- con
        // TextOverflow.Visible un nombre largo como "Venta de
        // Mercaderías" pinta bastante más allá de su caja nominal, así
        // que la detección de colisión de más abajo necesita este ancho
        // de verdad para no dejar pasar solapes que sí se ven en pantalla.
        val nodeLabelWidthsPx = nodes.indices.associateWith { idx ->
            val node = nodes[idx]
            val nameW = textMeasurer.measure(node.name, labelSmallStyle).size.width
            val valW = textMeasurer.measure(formatMoney(node.value, currency), bodySmallStyle).size.width
            maxOf(nameW, valW).toFloat()
        }

        fun labelSpanPx(idx: Int): Pair<Float, Float> {
            val layer = layerMap[idx] ?: centerLayer
            val w = nodeLabelWidthsPx[idx] ?: 32f
            val (boxX, boxW) = labelBoxByLayer[layer] ?: (0f to 40f)
            return when {
                idx == centerIdx -> {
                    val mid = boxX + boxW / 2f
                    (mid - w / 2f) to (mid + w / 2f)
                }
                layer < centerLayer -> boxX to (boxX + w)
                else -> (boxX + boxW - w) to (boxX + boxW)
            }
        }

        val labelYMap = mutableMapOf<Int, Dp>()
        val minSpacingPx = with(density) { 4.dp.toPx() }
        val minYPx = with(density) { 4.dp.toPx() }
        val maxYPx = heightPx - with(density) { 4.dp.toPx() }

        // Compute vertical positions PER LAYER to avoid cross-layer vertical collisions
        (0..maxLayer).forEach { layer ->
            val colNodeIndices = nodesByLayer[layer] ?: emptyList()
            if (colNodeIndices.isEmpty()) return@forEach

            val sortedByCenterY = colNodeIndices.mapNotNull { nodeLayouts[it] }.sortedBy { it.centerY }
            if (layer == centerLayer) {
                val centerLayout = sortedByCenterY.firstOrNull { it.nodeIdx == centerIdx } ?: sortedByCenterY.firstOrNull()
                if (centerLayout != null) {
                    val h = nodeLabelHeightsPx[centerLayout.nodeIdx] ?: 36f
                    val idealY = (centerLayout.centerY - h / 2f).coerceIn(minYPx, maxYPx - h)
                    labelYMap[centerLayout.nodeIdx] = with(density) { idealY.toDp() }
                }
            } else {
                val idealYs = sortedByCenterY.map { layout ->
                    val h = nodeLabelHeightsPx[layout.nodeIdx] ?: 32f
                    layout.centerY - h / 2f
                }
                val heights = sortedByCenterY.map { nodeLabelHeightsPx[it.nodeIdx] ?: 32f }
                val computedYs = computeVerticalLabelPositions(idealYs, heights, minSpacingPx, maxYPx, minYPx)
                sortedByCenterY.forEachIndexed { i, layout ->
                    labelYMap[layout.nodeIdx] = with(density) { computedYs[i].toDp() }
                }
            }
        }

        // El cálculo de arriba resuelve colisiones DENTRO de cada columna,
        // no ENTRE columnas vecinas -- y con las capas asignadas por
        // cantidad de saltos (no por índice fijo) cualquier columna puede
        // terminar compartiendo rango vertical Y horizontal con su vecina
        // (no solo el centro: ej. "Transporte" comparte columna con las
        // categorías de gasto que van directo al centro). Se resuelve
        // con pasadas de empuje pairwise entre todo par de labels cuyas
        // cajas se solapan horizontalmente, en vez de un caso especial
        // solo para el nodo central.
        val allIndices = nodes.indices.toList()
        repeat(8) {
            for (i in allIndices.indices) {
                for (j in i + 1 until allIndices.size) {
                    val a = allIndices[i]
                    val b = allIndices[j]
                    // Antes se saltaban los pares de la MISMA columna acá
                    // ("ya resueltos" por computeVerticalLabelPositions
                    // arriba) -- pero cuando este resolver mueve un nodo
                    // para esquivar al centro, puede romper el
                    // espaciado que esa función ya había dejado bien
                    // dentro de su propia columna, sin que nada lo vuelva
                    // a corregir. Ahora TODO par se resuelve acá, cruzado
                    // o no -- computeVerticalLabelPositions sigue siendo
                    // el punto de partida (respeta el orden por value),
                    // esto solo pule encima.
                    val (ax0, ax1) = labelSpanPx(a)
                    val (bx0, bx1) = labelSpanPx(b)
                    if (!(ax0 < bx1 && ax1 > bx0)) continue // sin solape horizontal real

                    val ah = nodeLabelHeightsPx[a] ?: 32f
                    val bh = nodeLabelHeightsPx[b] ?: 32f
                    var ay = with(density) { (labelYMap[a] ?: 0.dp).toPx() }
                    var by = with(density) { (labelYMap[b] ?: 0.dp).toPx() }

                    val vertOverlap = ay < by + bh + minSpacingPx && ay + ah > by - minSpacingPx
                    if (!vertOverlap) continue

                    val overlapAmount = (minSpacingPx + minOf(ay + ah, by + bh) - maxOf(ay, by)).coerceAtLeast(0f)

                    // El centro nunca se mueve -- su bar está centrado a
                    // propósito (pedido explícito) y con 5 categorías de
                    // gasto ahora compartiendo la columna vecina, dejar
                    // que el resolver lo empuje a él también generaba
                    // ping-pong entre pares que no convergía en pocas
                    // pasadas. Si uno de los dos es el centro, se empuja
                    // SIEMPRE al otro, el overlap completo.
                    when {
                        a == centerIdx -> {
                            by = if (by >= ay) (by + overlapAmount).coerceIn(minYPx, maxYPx - bh)
                                 else (by - overlapAmount).coerceIn(minYPx, maxYPx - bh)
                        }
                        b == centerIdx -> {
                            ay = if (ay >= by) (ay + overlapAmount).coerceIn(minYPx, maxYPx - ah)
                                 else (ay - overlapAmount).coerceIn(minYPx, maxYPx - ah)
                        }
                        else -> {
                            val push = overlapAmount / 2f
                            if (ay <= by) {
                                ay = (ay - push).coerceIn(minYPx, maxYPx - ah)
                                by = (by + push).coerceIn(minYPx, maxYPx - bh)
                            } else {
                                by = (by - push).coerceIn(minYPx, maxYPx - bh)
                                ay = (ay + push).coerceIn(minYPx, maxYPx - ah)
                            }
                        }
                    }
                    labelYMap[a] = with(density) { ay.toDp() }
                    labelYMap[b] = with(density) { by.toDp() }
                }
            }
        }

        Box(modifier = Modifier.fillMaxSize()) {
            nodeLayouts.values.forEach { layout ->
                val node = nodes[layout.nodeIdx]
                val layer = layout.layer
                val isCenterNode = layout.nodeIdx == centerIdx

                val labelHPx = nodeLabelHeightsPx[layout.nodeIdx] ?: 32f
                val yDp = labelYMap[layout.nodeIdx] ?: with(density) { (layout.centerY - labelHPx / 2f).toDp() }

                // Ancho de la etiqueta: ya viene exacto de columnWidths (medido
                // de verdad con TextMeasurer), no hay que recortar contra la
                // columna vecina como antes -- por eso ya no existen
                // centerLeftBoundPx/centerRightBoundPx/layerBarXMap.
                val (boxXPx, boxWPx) = labelBoxByLayer[layer] ?: (layout.x to 40f)
                val xDp = with(density) { boxXPx.toDp() }
                val wDp = with(density) { boxWPx.toDp() }

                if (isCenterNode) {
                    Box(
                        modifier = Modifier
                            .offset(x = xDp.coerceAtLeast(0.dp), y = yDp)
                            .width(wDp),
                        contentAlignment = Alignment.Center
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = true,
                            isCompact = false,
                            maxWidthDp = wDp,
                            nameStyle = labelSmallStyle,
                            valueStyle = bodySmallStyle,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                } else if (layer < centerLayer) {
                    Box(
                        modifier = Modifier
                            .offset(x = xDp, y = yDp)
                            .width(wDp)
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = false,
                            alignEnd = false,
                            isCompact = false,
                            maxWidthDp = wDp,
                            nameStyle = labelSmallStyle,
                            valueStyle = bodySmallStyle,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                } else { // layer > centerLayer
                    Box(
                        modifier = Modifier
                            .offset(x = xDp, y = yDp)
                            .width(wDp),
                        contentAlignment = Alignment.CenterEnd
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = false,
                            alignEnd = true,
                            isCompact = false,
                            maxWidthDp = wDp,
                            nameStyle = labelSmallStyle,
                            valueStyle = bodySmallStyle,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                }
            }
        }
    }
}

internal fun computeVerticalLabelPositions(
    idealYList: List<Float>,
    labelHeights: List<Float>,
    minSpacingPx: Float,
    maxYPx: Float,
    minYPx: Float = 0f
): List<Float> {
    if (idealYList.isEmpty()) return emptyList()
    val count = idealYList.size
    val positions = FloatArray(count) { idealYList[it] }

    // Pass 1: Forward push (top-to-bottom)
    for (i in 1 until count) {
        val minAllowed = positions[i - 1] + labelHeights[i - 1] + minSpacingPx
        if (positions[i] < minAllowed) {
            positions[i] = minAllowed
        }
    }

    // Pass 2: Backward push if bottom exceeds bounds (bottom-to-top)
    val maxBottom = maxYPx
    if (count > 0 && positions[count - 1] + labelHeights[count - 1] > maxBottom) {
        positions[count - 1] = maxBottom - labelHeights[count - 1]
        for (i in count - 2 downTo 0) {
            val maxAllowed = positions[i + 1] - labelHeights[i] - minSpacingPx
            if (positions[i] > maxAllowed) {
                positions[i] = maxAllowed
            }
        }
    }

    // Pass 3: Clamp top to minYPx and adjust downwards if needed
    if (count > 0 && positions[0] < minYPx) {
        positions[0] = minYPx
        for (i in 1 until count) {
            val minAllowed = positions[i - 1] + labelHeights[i - 1] + minSpacingPx
            if (positions[i] < minAllowed) {
                positions[i] = minAllowed
            }
        }
    }

    // Pass 4: Compression / scaling pass if bottom STILL exceeds maxBottom after Pass 3
    if (count > 0 && positions[count - 1] + labelHeights[count - 1] > maxBottom) {
        val availableHeight = maxBottom - minYPx
        val totalLabelHeight = labelHeights.sum()

        if (totalLabelHeight < availableHeight && count > 1) {
            val dynamicSpacing = (availableHeight - totalLabelHeight) / (count - 1)
            positions[0] = minYPx
            for (i in 1 until count) {
                positions[i] = positions[i - 1] + labelHeights[i - 1] + dynamicSpacing
            }
        } else if (availableHeight > 0f) {
            val currentSpan = (positions[count - 1] + labelHeights[count - 1] - positions[0]).coerceAtLeast(1f)
            val scale = (availableHeight - labelHeights[count - 1]) / (currentSpan - labelHeights[count - 1]).coerceAtLeast(1f)
            val base = positions[0]
            for (i in 0 until count) {
                positions[i] = minYPx + (positions[i] - base) * scale
            }
        }
    }

    return positions.toList()
}

@Composable
private fun SankeyNodeLabel(
    node: SankeyNodeDto,
    currency: String,
    isCenter: Boolean = false,
    alignEnd: Boolean = false,
    isCompact: Boolean = false,
    maxWidthDp: Dp,
    nameStyle: TextStyle,
    valueStyle: TextStyle,
    successColor: Color,
    destructiveColor: Color,
    warningColor: Color,
    primaryColor: Color,
    textSecondaryColor: Color
) {
    val nodeColor = parseColorString(
        node.color, textSecondaryColor, successColor, destructiveColor, warningColor, primaryColor
    )

    val horizAlignment = when {
        isCenter -> Alignment.CenterHorizontally
        alignEnd -> Alignment.End
        else -> Alignment.Start
    }
    val textAlign = when {
        isCenter -> TextAlign.Center
        alignEnd -> TextAlign.End
        else -> TextAlign.Start
    }

    Row(
        modifier = Modifier.width(maxWidthDp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = if (alignEnd) Arrangement.End else if (isCenter) Arrangement.Center else Arrangement.Start
    ) {
        if (!isCenter && !alignEnd) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(nodeColor, CircleShape)
            )
            Spacer(modifier = Modifier.width(4.dp))
        }
        Column(
            modifier = Modifier.weight(1f, fill = false),
            horizontalAlignment = horizAlignment
        ) {
            // overflow=Visible + softWrap=false -- igual que la web (d3-sankey
            // dibuja el texto suelto al lado del nodo, sin caja que lo
            // recorte): el nombre nunca se corta con ellipsis, en el peor
            // caso se superpone a la columna vecina antes que perder
            // información.
            if (isCompact && !isCenter) {
                Text(
                    text = "${node.name} • ${formatMoney(node.value, currency)}",
                    style = nameStyle,
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    softWrap = false,
                    overflow = TextOverflow.Visible,
                    textAlign = textAlign
                )
            } else {
                Text(
                    text = node.name,
                    style = nameStyle,
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    softWrap = false,
                    overflow = TextOverflow.Visible,
                    textAlign = textAlign
                )
                Text(
                    text = formatMoney(node.value, currency),
                    style = valueStyle,
                    color = FinancePyColors.textSecondary(),
                    maxLines = 1,
                    softWrap = false,
                    overflow = TextOverflow.Visible,
                    textAlign = textAlign
                )
            }
        }
        if (!isCenter && alignEnd) {
            Spacer(modifier = Modifier.width(4.dp))
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(nodeColor, CircleShape)
            )
        }
    }
}
