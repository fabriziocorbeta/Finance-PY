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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
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

private data class NodeLayout(
    val nodeIdx: Int,
    val layer: Int,
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
    val centerY: Float
)

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
                SankeyCanvasLayout(
                    sankeyDto = sankeyDto!!,
                    currency = currency,
                    modifier = Modifier.fillMaxWidth().height(280.dp)
                )
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

        Box(modifier = Modifier.fillMaxSize()) {
            nodeLayouts.values.forEach { layout ->
                val node = nodes[layout.nodeIdx]
                val isLeftHalf = layout.x < widthPx / 2f
                val isCenterNode = layout.nodeIdx == centerIdx

                val xDp = with(density) { layout.x.toDp() }
                val yDp = with(density) { layout.centerY.toDp() }
                val barWidthDp = with(density) { barWidth.toDp() }

                if (isCenterNode) {
                    Box(
                        modifier = Modifier
                            .offset(x = (xDp - 50.dp).coerceAtLeast(0.dp), y = yDp - 14.dp)
                            .width(110.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = true,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                } else if (isLeftHalf) {
                    Box(
                        modifier = Modifier
                            .offset(x = xDp + barWidthDp + 4.dp, y = yDp - 14.dp)
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = false,
                            alignEnd = false,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            textSecondaryColor = textSecondaryColor
                        )
                    }
                } else {
                    Box(
                        modifier = Modifier
                            .offset(x = (xDp - 120.dp).coerceAtLeast(0.dp), y = yDp - 14.dp)
                            .width(116.dp),
                        contentAlignment = Alignment.CenterEnd
                    ) {
                        SankeyNodeLabel(
                            node = node,
                            currency = currency,
                            isCenter = false,
                            alignEnd = true,
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

@Composable
private fun SankeyNodeLabel(
    node: SankeyNodeDto,
    currency: String,
    isCenter: Boolean = false,
    alignEnd: Boolean = false,
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

    Row(
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
        Column(horizontalAlignment = horizAlignment) {
            Text(
                text = node.name,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textPrimary(),
                maxLines = 1
            )
            Text(
                text = formatMoney(node.value, currency),
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary(),
                maxLines = 1
            )
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
