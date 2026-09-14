package py.com.cdco.financespy

import py.com.cdco.financespy.api.dto.CashflowSankeyDto
import py.com.cdco.financespy.api.dto.SankeyLinkDto
import py.com.cdco.financespy.api.dto.SankeyNodeDto
import py.com.cdco.financespy.screens.components.computeVerticalLabelPositions
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SankeyFlowChartTest {

    @Test
    fun testComputeVerticalLabelPositions_SimpleScenario() {
        val idealYs = listOf(20f, 100f, 200f)
        val heights = listOf(30f, 30f, 30f)
        val minSpacing = 4f
        val maxY = 280f
        val minY = 4f

        val positions = computeVerticalLabelPositions(idealYs, heights, minSpacing, maxY, minY)

        assertEquals(3, positions.size)
        assertEquals(20f, positions[0])
        assertEquals(100f, positions[1])
        assertEquals(200f, positions[2])
    }

    @Test
    fun testComputeVerticalLabelPositions_BusinessModeScenarioWithOverlapAndOverflow() {
        // 6 nodes closely stacked near bottom
        val idealYs = listOf(150f, 170f, 190f, 210f, 230f, 250f)
        val heights = listOf(32f, 32f, 32f, 32f, 32f, 32f)
        val minSpacing = 4f
        val maxY = 280f
        val minY = 4f

        val positions = computeVerticalLabelPositions(idealYs, heights, minSpacing, maxY, minY)

        assertEquals(6, positions.size)
        // Ensure no adjacent overlap
        for (i in 0 until positions.size - 1) {
            assertTrue(
                positions[i + 1] >= positions[i] + heights[i] + minSpacing,
                "Label $i and ${i + 1} overlap: pos[$i]=${positions[i]}, pos[${i + 1}]=${positions[i + 1]}"
            )
        }
        // Ensure within container bounds
        assertTrue(positions.first() >= minY, "Top label out of bounds: ${positions.first()}")
        assertTrue(
            positions.last() + heights.last() <= maxY,
            "Bottom label out of bounds: ${positions.last() + heights.last()} > $maxY"
        )
    }

    @Test
    fun testComputeVerticalLabelPositions_DenseNodeCount() {
        // 8 nodes in a column exceeding total uncompressed height
        val count = 8
        val idealYs = List(count) { i -> 20f + i * 25f }
        val heights = List(count) { 32f }
        val minSpacing = 4f
        val maxY = 280f
        val minY = 4f

        val positions = computeVerticalLabelPositions(idealYs, heights, minSpacing, maxY, minY)

        assertEquals(count, positions.size)
        // Check top and bottom bounds
        assertTrue(positions.first() >= minY, "Top label out of bounds: ${positions.first()} < $minY")
        assertTrue(
            positions.last() + heights.last() <= maxY,
            "Bottom label out of bounds: ${positions.last() + heights.last()} > $maxY"
        )
        // Ensure non-overlapping ordering
        for (i in 0 until count - 1) {
            assertTrue(
                positions[i + 1] >= positions[i] + heights[i],
                "Label $i and ${i + 1} overlap: pos[$i]=${positions[i]}, pos[${i + 1}]=${positions[i + 1]}"
            )
        }
    }

    @Test
    fun testSankeyLayout_BusinessModeMultiColumn() {
        // Construct a Business Mode Sankey DTO with income category/subcategory and expense categories/subcategories
        val nodes = listOf(
            SankeyNodeDto(name = "Venta de Mercaderías", value = 5000000.0, color = "#10A861"), // 0: Income Sub
            SankeyNodeDto(name = "Ventas", value = 5000000.0, color = "#10A861"),               // 1: Income Cat
            SankeyNodeDto(name = "Flujo de caja", value = 5000000.0, color = "#9E9E9E"),        // 2: Center
            SankeyNodeDto(name = "Transportation", value = 2000000.0, color = "#EC2222"),       // 3: Expense Cat
            SankeyNodeDto(name = "Combustible", value = 1200000.0, color = "#EC2222"),          // 4: Expense Sub
            SankeyNodeDto(name = "Seguro Sportage", value = 800000.0, color = "#EC2222"),       // 5: Expense Sub
            SankeyNodeDto(name = "Healthcare", value = 1000000.0, color = "#EC2222"),           // 6: Expense Cat
            SankeyNodeDto(name = "Fees", value = 500000.0, color = "#EC2222"),                 // 7: Expense Cat
            SankeyNodeDto(name = "Schatzi ❤️", value = 1500000.0, color = "#EC2222")           // 8: Expense Cat
        )

        val links = listOf(
            SankeyLinkDto(source = 0, target = 1, value = 5000000.0, color = "#10A861"), // Income Sub -> Income Cat
            SankeyLinkDto(source = 1, target = 2, value = 5000000.0, color = "#10A861"), // Income Cat -> Center
            SankeyLinkDto(source = 2, target = 3, value = 2000000.0, color = "#EC2222"), // Center -> Expense Cat
            SankeyLinkDto(source = 3, target = 4, value = 1200000.0, color = "#EC2222"), // Expense Cat -> Expense Sub
            SankeyLinkDto(source = 3, target = 5, value = 800000.0, color = "#EC2222"),  // Expense Cat -> Expense Sub
            SankeyLinkDto(source = 2, target = 6, value = 1000000.0, color = "#EC2222"), // Center -> Expense Cat
            SankeyLinkDto(source = 2, target = 7, value = 500000.0, color = "#EC2222"),  // Center -> Expense Cat
            SankeyLinkDto(source = 2, target = 8, value = 1500000.0, color = "#EC2222")  // Center -> Expense Cat
        )

        val dto = CashflowSankeyDto(nodes = nodes, links = links)

        // Verify layer detection logic:
        val centerIdx = dto.nodes.indexOfFirst { it.name.contains("Flujo de caja", ignoreCase = true) }
        assertEquals(2, centerIdx)

        // Verify links and nodes are properly non-empty
        assertTrue(dto.nodes.size >= 8)
        assertTrue(dto.links.isNotEmpty())
    }
}
