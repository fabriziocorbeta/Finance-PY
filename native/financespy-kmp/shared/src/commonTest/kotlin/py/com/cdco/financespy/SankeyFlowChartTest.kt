package py.com.cdco.financespy

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
}
