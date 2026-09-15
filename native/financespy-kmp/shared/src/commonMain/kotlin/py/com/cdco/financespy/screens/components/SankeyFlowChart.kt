package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
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
            if (hasIncomeSubs) {
                layerMap[idx] = if (hasIncoming) 1 else 0
            } else {
                layerMap[idx] = 0
            }
        } else {
            val hasOutgoing = outgoingMap[idx]?.isNotEmpty() == true
            if (hasOutgoing) {
                layerMap[idx] = centerLayer + 1
            } else {
                layerMap[idx] = maxLayer
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
                // 56dp/nodo (antes 44dp): con el modo compacto deshabilitado,
                // cada label ahora es siempre 2 líneas (nombre + monto) en
                // vez de 1 -- ese alto extra hay que reservarlo acá o las
                // etiquetas de columnas con muchos nodos se pisan entre sí.
                val cappedDto = remember(sankeyDto) { capNodesPerLayer(sankeyDto!!) }
                val maxNodesInColumn = maxNodesInAnyLayer(cappedDto)
                val chartHeight = maxOf(280.dp, (maxNodesInColumn * 56).dp)

                // Repartir el ancho de pantalla entre las columnas (colSpacing)
                // nunca convergió: con 4 columnas (ingresos con sub-categorías +
                // gastos) no hay forma de darle a cada una ancho legible sin
                // angostar a las demás -- ya se intentó achicar la etiqueta
                // central y sacar el modo compacto, mejoró pero seguía apretado.
                // En vez de seguir repartiendo un ancho fijo insuficiente, cada
                // columna recibe un ancho cómodo fijo (130dp) y el gráfico entero
                // scrollea horizontalmente cuando no entra en la pantalla.
                val maxLayer = remember(cappedDto) { computeSankeyLayers(cappedDto).maxLayer }
                val naturalChartWidth = ((maxLayer + 1) * 130).dp
                BoxWithConstraints {
                    // maxWidth acá es el ancho real disponible (la card) -- si
                    // el ancho natural (130dp x columna) entra, usamos ese
                    // disponible tal cual (mismo comportamiento que antes,
                    // fillMaxWidth). Si no entra, el chart crece más allá de
                    // la pantalla y el Box de abajo lo hace scrolleable.
                    val chartWidth = maxOf(maxWidth, naturalChartWidth)
                    Box(modifier = Modifier.horizontalScroll(rememberScrollState())) {
                        SankeyCanvasLayout(
                            sankeyDto = cappedDto,
                            currency = currency,
                            modifier = Modifier.width(chartWidth).height(chartHeight)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SankeyCanvasLayout(
    sankeyDto: CashflowSankeyDto,
    currency: String,
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

    val layerInfo = computeSankeyLayers(sankeyDto)
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

        val barWidth = with(density) { 10.dp.toPx() }
        val edgeMargin = with(density) { 16.dp.toPx() }
        val colSpacing = if (maxLayer > 0) (widthPx - 2 * edgeMargin - barWidth) / maxLayer else 0f

        val nodesByLayer = nodes.indices.groupBy { layerMap[it] ?: centerLayer }
        val nodeLayouts = mutableMapOf<Int, NodeLayout>()

        (0..maxLayer).forEach { layer ->
            val colNodeIndices = nodesByLayer[layer] ?: emptyList()
            if (colNodeIndices.isEmpty()) return@forEach

            val colX = edgeMargin + layer * colSpacing
            val colTotalVal = colNodeIndices.sumOf { nodes[it].value }.let { if (it <= 0) 1.0 else it }

            val verticalMargin = with(density) { 20.dp.toPx() }
            val gap = if (colNodeIndices.size > 1) with(density) { 12.dp.toPx() } else 0f
            val availableH = (heightPx - 2 * verticalMargin - (colNodeIndices.size - 1) * gap).coerceAtLeast(20f)

            var currentY = verticalMargin
            colNodeIndices.forEach { nodeIdx ->
                val node = nodes[nodeIdx]
                val nodeH = if (nodeIdx == centerIdx) {
                    (heightPx * 0.45f).coerceAtLeast(36f)
                } else {
                    ((node.value / colTotalVal) * availableH).toFloat().coerceAtLeast(8f)
                }

                val nodeLayout = NodeLayout(
                    nodeIdx = nodeIdx,
                    layer = layer,
                    x = colX,
                    y = currentY,
                    width = barWidth,
                    height = nodeH,
                    centerY = currentY + nodeH / 2f
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

            links.forEach { link ->
                val srcLayout = nodeLayouts[link.source] ?: return@forEach
                val dstLayout = nodeLayouts[link.target] ?: return@forEach

                val outgoingLinksForSrc = outgoingMap[link.source] ?: emptyList()
                val incomingLinksForDst = incomingMap[link.target] ?: emptyList()

                val srcIndexInOutgoing = outgoingLinksForSrc.indexOf(link).coerceAtLeast(0)
                val dstIndexInIncoming = incomingLinksForDst.indexOf(link).coerceAtLeast(0)

                val srcY = if (outgoingLinksForSrc.size > 1) {
                    srcLayout.y + (srcIndexInOutgoing + 0.5f) * (srcLayout.height / outgoingLinksForSrc.size)
                } else {
                    srcLayout.centerY
                }

                val dstY = if (incomingLinksForDst.size > 1) {
                    dstLayout.y + (dstIndexInIncoming + 0.5f) * (dstLayout.height / incomingLinksForDst.size)
                } else {
                    dstLayout.centerY
                }

                val startX = srcLayout.x + barWidth
                val endX = dstLayout.x
                val dx = (endX - startX).coerceAtLeast(4f)

                val path = Path().apply {
                    moveTo(startX, srcY)
                    cubicTo(
                        startX + dx * 0.5f, srcY,
                        startX + dx * 0.5f, dstY,
                        endX, dstY
                    )
                }

                val strokeW = (minOf(srcLayout.height, dstLayout.height) * 0.6f).coerceIn(2f, 18f)
                val rawLinkColor = parseColorString(
                    link.color, defaultColor, successColor, destructiveColor, warningColor, primaryColor
                )
                val linkColor = rawLinkColor.copy(alpha = 0.4f)

                drawPath(path = path, color = linkColor, style = Stroke(width = strokeW))
            }
        }

        val textMeasurer = rememberTextMeasurer()
        val labelSmallStyle = MaterialTheme.typography.labelSmall
        val bodySmallStyle = MaterialTheme.typography.bodySmall

        // El modo compacto (concatenar "nombre • monto" en una sola línea para
        // ahorrar altura en columnas con muchos nodos) se probó y revirtió una
        // vez ya (threshold >=4 -> >4) intentando arreglar el ancho, pero el
        // problema de fondo es el modo en sí: pide MÁS ancho horizontal por
        // línea justo en las columnas que YA tienen menos ancho disponible
        // (las adyacentes al centro). Deshabilitado del todo -- siempre 2
        // líneas (nombre / monto), cada una más corta que el combo. El costo
        // en altura que esto agrega se compensa en chartHeight más abajo.
        val isCompactLayerMap = (0..maxLayer).associateWith { false }

        val nodeLabelHeightsPx = nodes.indices.associateWith { idx ->
            val node = nodes[idx]
            val layer = layerMap[idx] ?: centerLayer
            val isCompact = isCompactLayerMap[layer] == true && idx != centerIdx
            if (isCompact) {
                val lineH = textMeasurer.measure("${node.name} • ${formatMoney(node.value, currency)}", labelSmallStyle).size.height
                lineH.toFloat()
            } else {
                val titleH = textMeasurer.measure(node.name, labelSmallStyle).size.height
                val valH = textMeasurer.measure(formatMoney(node.value, currency), bodySmallStyle).size.height
                (titleH + valH).toFloat()
            }
        }

        val centerNodeLayout = nodeLayouts[centerIdx]
        // El ancho de la etiqueta central era fijo en 100dp sin importar cuántas
        // capas hubiera. Con 4 columnas (ingresos con sub-categorías + gastos, el
        // caso reportado) esa caja fija de 100dp deja a las columnas ADYACENTES
        // al centro con ~31dp reales de ancho (el piso mínimo del código de abajo),
        // de ahí el truncamiento severo ("Com...", "Seg..."). Con 2-3 columnas
        // (colSpacing más generoso) 100dp entra sin apretar a nadie, así que solo
        // se achica cuando realmente hace falta.
        val centerLabelWidthPx = if (maxLayer > 2) {
            with(density) { 70.dp.toPx() }
        } else {
            with(density) { 100.dp.toPx() }
        }
        val centerLabelWidthDp = with(density) { centerLabelWidthPx.toDp() }
        val centerBarX = centerNodeLayout?.x ?: (widthPx / 2f)

        val centerLeftBoundPx = centerBarX - (centerLabelWidthPx / 2f) - with(density) { 4.dp.toPx() }
        val centerRightBoundPx = centerBarX + barWidth + (centerLabelWidthPx / 2f) + with(density) { 4.dp.toPx() }

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

        val layerBarXMap = (0..maxLayer).associateWith { layer ->
            val layoutsInLayer = nodeLayouts.values.filter { it.layer == layer }
            layoutsInLayer.firstOrNull()?.x ?: (edgeMargin + layer * colSpacing)
        }

        Box(modifier = Modifier.fillMaxSize()) {
            nodeLayouts.values.forEach { layout ->
                val node = nodes[layout.nodeIdx]
                val layer = layout.layer
                val isCenterNode = layout.nodeIdx == centerIdx
                val isCompact = isCompactLayerMap[layer] == true && !isCenterNode

                val labelHPx = nodeLabelHeightsPx[layout.nodeIdx] ?: 32f
                val yDp = labelYMap[layout.nodeIdx] ?: with(density) { (layout.centerY - labelHPx / 2f).toDp() }

                if (isCenterNode) {
                    val centerOffsetX = with(density) { (centerBarX - centerLabelWidthPx / 2f + barWidth / 2f).toDp() }
                    Box(
                        modifier = Modifier
                            .offset(x = centerOffsetX.coerceAtLeast(0.dp), y = yDp)
                            .width(centerLabelWidthDp),
                        contentAlignment = Alignment.Center
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = true,
                            isCompact = false,
                            maxWidthDp = centerLabelWidthDp,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                } else if (layer < centerLayer) {
                    val startXPx = layout.x + barWidth + with(density) { 4.dp.toPx() }
                    val nextLayerX = layerBarXMap[layer + 1]
                    val endBoundPx = if (layer + 1 == centerLayer || nextLayerX == null) {
                        centerLeftBoundPx
                    } else {
                        nextLayerX - with(density) { 4.dp.toPx() }
                    }
                    val maxW = (endBoundPx - startXPx).coerceAtLeast(with(density) { 30.dp.toPx() })
                    val maxWDp = with(density) { maxW.toDp() }
                    val xDp = with(density) { startXPx.toDp() }

                    Box(
                        modifier = Modifier
                            .offset(x = xDp, y = yDp)
                            .width(maxWDp)
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = false,
                            alignEnd = false,
                            isCompact = isCompact,
                            maxWidthDp = maxWDp,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                } else { // layer > centerLayer
                    val endXPx = layout.x - with(density) { 4.dp.toPx() }
                    val prevLayerX = layerBarXMap[layer - 1]
                    val startBoundPx = if (layer - 1 == centerLayer || prevLayerX == null) {
                        centerRightBoundPx
                    } else {
                        prevLayerX + barWidth + with(density) { 4.dp.toPx() }
                    }
                    val maxW = (endXPx - startBoundPx).coerceAtLeast(with(density) { 30.dp.toPx() })
                    val maxWDp = with(density) { maxW.toDp() }
                    val boxStartXPx = (endXPx - maxW).coerceAtLeast(startBoundPx)
                    val boxStartWDp = with(density) { boxStartXPx.toDp() }

                    Box(
                        modifier = Modifier
                            .offset(x = boxStartWDp, y = yDp)
                            .width(maxWDp),
                        contentAlignment = Alignment.CenterEnd
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = false,
                            alignEnd = true,
                            isCompact = isCompact,
                            maxWidthDp = maxWDp,
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
            if (isCompact && !isCenter) {
                Text(
                    text = "${node.name} • ${formatMoney(node.value, currency)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = textAlign
                )
            } else {
                Text(
                    text = node.name,
                    style = MaterialTheme.typography.labelSmall,
                    color = FinancePyColors.textPrimary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = textAlign
                )
                Text(
                    text = formatMoney(node.value, currency),
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary(),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
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
