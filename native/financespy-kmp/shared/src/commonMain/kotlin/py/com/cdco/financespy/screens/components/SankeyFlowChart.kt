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

@Composable
fun SankeyFlowChart(
    sankeyDto: CashflowSankeyDto?,
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
                    modifier = Modifier.fillMaxWidth().height(280.dp)
                )
            }
        }
    }
}

@Composable
private fun SankeyCanvasLayout(
    sankeyDto: CashflowSankeyDto,
    modifier: Modifier = Modifier
) {
    val nodes = sankeyDto.nodes
    val links = sankeyDto.links
    val currencySymbol = sankeyDto.currency_symbol ?: "₲"

    val successColor = FinancePyColors.success()
    val destructiveColor = FinancePyColors.destructive()
    val warningColor = FinancePyColors.warning()
    val primaryColor = FinancePyColors.buttonBgPrimary()
    val textSecondaryColor = FinancePyColors.textSecondary()

    val centerNode = nodes.getOrNull(0) ?: SankeyNodeDto(name = "Flujo de caja", value = 0.0)

    val incomeLinks = links.filter { it.target == 0 }
    val expenseLinks = links.filter { it.source == 0 }

    val incomeNodesWithLinks = incomeLinks.mapNotNull { link ->
        nodes.getOrNull(link.source)?.let { node -> Pair(node, link) }
    }

    val expenseNodesWithLinks = expenseLinks.mapNotNull { link ->
        nodes.getOrNull(link.target)?.let { node -> Pair(node, link) }
    }

    val totalIncomeValue = incomeNodesWithLinks.sumOf { it.first.value }.let { if (it <= 0) 1.0 else it }
    val totalExpenseValue = expenseNodesWithLinks.sumOf { it.first.value }.let { if (it <= 0) 1.0 else it }

    val density = LocalDensity.current

    BoxWithConstraints(modifier = modifier) {
        val widthPx = constraints.maxWidth.toFloat()
        val heightPx = constraints.maxHeight.toFloat()

        val leftX = with(density) { 16.dp.toPx() }
        val centerX = widthPx / 2f
        val rightX = widthPx - with(density) { 16.dp.toPx() }
        val barWidth = with(density) { 12.dp.toPx() }

        Canvas(modifier = Modifier.fillMaxSize()) {
            val incomeGap = 16.dp.toPx()
            val totalIncomeGaps = ((incomeNodesWithLinks.size - 1).coerceAtLeast(0)) * incomeGap
            val availableIncomeH = (heightPx - totalIncomeGaps - 40.dp.toPx()).coerceAtLeast(20f)

            var currentIncomeY = 20.dp.toPx()
            val incomePositions = mutableMapOf<Int, Pair<Offset, Float>>()

            incomeNodesWithLinks.forEachIndexed { idx, (node, link) ->
                val nodeH = ((node.value / totalIncomeValue) * availableIncomeH).toFloat().coerceAtLeast(8f)
                val nodeTopLeft = Offset(leftX, currentIncomeY)

                val nodeColor = parseColorString(
                    node.color, successColor, successColor, destructiveColor, warningColor, primaryColor
                )

                drawRoundRect(
                    color = nodeColor,
                    topLeft = nodeTopLeft,
                    size = Size(barWidth, nodeH),
                    cornerRadius = CornerRadius(4f, 4f)
                )

                incomePositions[idx] = Pair(Offset(leftX + barWidth, currentIncomeY + nodeH / 2f), nodeH)
                currentIncomeY += nodeH + incomeGap
            }

            val centerH = (heightPx * 0.5f).coerceAtLeast(40f)
            val centerTopLeft = Offset(centerX - barWidth / 2f, (heightPx - centerH) / 2f)
            val centerNodeColor = parseColorString(
                centerNode.color, successColor, successColor, destructiveColor, warningColor, primaryColor
            )

            drawRoundRect(
                color = centerNodeColor,
                topLeft = centerTopLeft,
                size = Size(barWidth, centerH),
                cornerRadius = CornerRadius(4f, 4f)
            )

            val centerLeftPoint = Offset(centerX - barWidth / 2f, heightPx / 2f)
            val centerRightPoint = Offset(centerX + barWidth / 2f, heightPx / 2f)

            val expenseGap = 16.dp.toPx()
            val totalExpenseGaps = ((expenseNodesWithLinks.size - 1).coerceAtLeast(0)) * expenseGap
            val availableExpenseH = (heightPx - totalExpenseGaps - 40.dp.toPx()).coerceAtLeast(20f)

            var currentExpenseY = 20.dp.toPx()
            val expensePositions = mutableMapOf<Int, Pair<Offset, Float>>()

            expenseNodesWithLinks.forEachIndexed { idx, (node, link) ->
                val nodeH = ((node.value / totalExpenseValue) * availableExpenseH).toFloat().coerceAtLeast(8f)
                val nodeTopLeft = Offset(rightX - barWidth, currentExpenseY)

                val nodeColor = parseColorString(
                    node.color, destructiveColor, successColor, destructiveColor, warningColor, primaryColor
                )

                drawRoundRect(
                    color = nodeColor,
                    topLeft = nodeTopLeft,
                    size = Size(barWidth, nodeH),
                    cornerRadius = CornerRadius(4f, 4f)
                )

                expensePositions[idx] = Pair(Offset(rightX - barWidth, currentExpenseY + nodeH / 2f), nodeH)
                currentExpenseY += nodeH + expenseGap
            }

            incomeNodesWithLinks.forEachIndexed { idx, (_, link) ->
                val (srcOffset, nodeH) = incomePositions[idx] ?: return@forEachIndexed
                val strokeW = (nodeH * 0.8f).coerceIn(2f, 24f)
                val rawLinkColor = parseColorString(
                    link.color, successColor, successColor, destructiveColor, warningColor, primaryColor
                )
                val linkColor = rawLinkColor.copy(alpha = 0.4f)

                val path = Path().apply {
                    moveTo(srcOffset.x, srcOffset.y)
                    cubicTo(
                        srcOffset.x + (centerLeftPoint.x - srcOffset.x) * 0.5f, srcOffset.y,
                        srcOffset.x + (centerLeftPoint.x - srcOffset.x) * 0.5f, centerLeftPoint.y,
                        centerLeftPoint.x, centerLeftPoint.y
                    )
                }
                drawPath(path = path, color = linkColor, style = Stroke(width = strokeW))
            }

            expenseNodesWithLinks.forEachIndexed { idx, (_, link) ->
                val (dstOffset, nodeH) = expensePositions[idx] ?: return@forEachIndexed
                val strokeW = (nodeH * 0.8f).coerceIn(2f, 24f)
                val rawLinkColor = parseColorString(
                    link.color, destructiveColor, successColor, destructiveColor, warningColor, primaryColor
                )
                val linkColor = rawLinkColor.copy(alpha = 0.4f)

                val path = Path().apply {
                    moveTo(centerRightPoint.x, centerRightPoint.y)
                    cubicTo(
                        centerRightPoint.x + (dstOffset.x - centerRightPoint.x) * 0.5f, centerRightPoint.y,
                        centerRightPoint.x + (dstOffset.x - centerRightPoint.x) * 0.5f, dstOffset.y,
                        dstOffset.x, dstOffset.y
                    )
                }
                drawPath(path = path, color = linkColor, style = Stroke(width = strokeW))
            }
        }

        Row(
            modifier = Modifier.fillMaxSize(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 24.dp, top = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                incomeNodesWithLinks.forEach { (node, _) ->
                    SankeyNodeLabel(
                        node = node,
                        currencySymbol = currencySymbol,
                        successColor = successColor,
                        destructiveColor = destructiveColor,
                        warningColor = warningColor,
                        primaryColor = primaryColor,
                        textSecondaryColor = textSecondaryColor
                    )
                }
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(top = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                SankeyNodeLabel(
                    node = centerNode,
                    currencySymbol = currencySymbol,
                    isCenter = true,
                    successColor = successColor,
                    destructiveColor = destructiveColor,
                    warningColor = warningColor,
                    primaryColor = primaryColor,
                    textSecondaryColor = textSecondaryColor
                )
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 24.dp, top = 8.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                expenseNodesWithLinks.forEach { (node, _) ->
                    SankeyNodeLabel(
                        node = node,
                        currencySymbol = currencySymbol,
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

@Composable
private fun SankeyNodeLabel(
    node: SankeyNodeDto,
    currencySymbol: String,
    isCenter: Boolean = false,
    successColor: Color,
    destructiveColor: Color,
    warningColor: Color,
    primaryColor: Color,
    textSecondaryColor: Color
) {
    val nodeColor = parseColorString(
        node.color, textSecondaryColor, successColor, destructiveColor, warningColor, primaryColor
    )

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = if (isCenter) Arrangement.Center else Arrangement.Start
    ) {
        if (!isCenter) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(nodeColor, CircleShape)
            )
            Spacer(modifier = Modifier.width(4.dp))
        }
        Column(horizontalAlignment = if (isCenter) Alignment.CenterHorizontally else Alignment.Start) {
            Text(
                text = node.name,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = formatMoney(node.value, currencySymbol),
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary()
            )
        }
    }
}
