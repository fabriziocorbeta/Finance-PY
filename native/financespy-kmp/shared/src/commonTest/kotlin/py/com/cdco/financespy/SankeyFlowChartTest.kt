package py.com.cdco.financespy

import py.com.cdco.financespy.api.dto.CashflowSankeyDto
import py.com.cdco.financespy.api.dto.SankeyLinkDto
import py.com.cdco.financespy.api.dto.SankeyNodeDto
import py.com.cdco.financespy.screens.components.computeVerticalLabelPositions
import py.com.cdco.financespy.screens.components.capNodesPerLayer
import py.com.cdco.financespy.screens.components.maxNodesInAnyLayer
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

    // Reproduce el caso real reportado: Transportation/Healthcare/Fees/
    // Schatzi (4 categorías de gasto) apiladas en la misma columna hacían
    // que sus labels de 2 líneas se pisaran entre sí y con la columna
    // vecina de subcategorías (Combustible/Seguro). El fix agrega altura
    // dinámica según la columna más cargada -- este test fija ese cálculo.
    @Test
    fun testMaxNodesInAnyLayer_matchesDensestColumn() {
        val nodes = listOf(
            SankeyNodeDto(name = "Venta de Mercaderías", value = 5000000.0, color = "#10A861"),
            SankeyNodeDto(name = "Ventas", value = 5000000.0, color = "#10A861"),
            SankeyNodeDto(name = "Flujo de caja", value = 5000000.0, color = "#9E9E9E"),
            SankeyNodeDto(name = "Transportation", value = 2000000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Combustible", value = 1200000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Seguro Sportage", value = 800000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Healthcare", value = 1000000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Fees", value = 500000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Schatzi ❤️", value = 1500000.0, color = "#EC2222")
        )

        val links = listOf(
            SankeyLinkDto(source = 0, target = 1, value = 5000000.0, color = "#10A861"),
            SankeyLinkDto(source = 1, target = 2, value = 5000000.0, color = "#10A861"),
            SankeyLinkDto(source = 2, target = 3, value = 2000000.0, color = "#EC2222"),
            SankeyLinkDto(source = 3, target = 4, value = 1200000.0, color = "#EC2222"),
            SankeyLinkDto(source = 3, target = 5, value = 800000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 6, value = 1000000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 7, value = 500000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 8, value = 1500000.0, color = "#EC2222")
        )

        val dto = CashflowSankeyDto(nodes = nodes, links = links)

        // Transportation, Healthcare, Fees, Schatzi caen en la misma columna
        // (centerLayer + 1) -- 4 nodos, la columna más cargada del diagrama.
        assertEquals(4, maxNodesInAnyLayer(dto))
    }

    // Reproduce el segundo reporte (más grave que el primero): con 7
    // categorías de gasto reales en una sola columna, ni el alto dinámico
    // ni bajar el umbral de modo compacto alcanzaban -- las labels
    // terminaban truncadas incluso en el lado de ingresos ("Sala...",
    // "Tr... ₲..."). Fix real: acotar cada columna a un techo fijo de
    // nodos, agrupando el resto en "Otros".
    @Test
    fun testCapNodesPerLayer_groupsExcessIntoOtros() {
        val nodes = listOf(
            SankeyNodeDto(name = "Salario", value = 9300000.0, color = "#10A861"),
            SankeyNodeDto(name = "Venta de Mercaderías", value = 1220000.0, color = "#10A861"),
            SankeyNodeDto(name = "Flujo de caja", value = 2150000.0, color = "#9E9E9E"),
            SankeyNodeDto(name = "Comisión bancaria", value = 900000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Seguro Sportage", value = 800000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Healthcare", value = 700000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Fees", value = 600000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Transportation", value = 500000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Schatzi", value = 400000.0, color = "#EC2222"),
            SankeyNodeDto(name = "Sin categoría", value = 100000.0, color = "#EC2222")
        )

        val links = listOf(
            SankeyLinkDto(source = 0, target = 2, value = 9300000.0, color = "#10A861"),
            SankeyLinkDto(source = 1, target = 2, value = 1220000.0, color = "#10A861"),
            SankeyLinkDto(source = 2, target = 3, value = 900000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 4, value = 800000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 5, value = 700000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 6, value = 600000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 7, value = 500000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 8, value = 400000.0, color = "#EC2222"),
            SankeyLinkDto(source = 2, target = 9, value = 100000.0, color = "#EC2222")
        )

        val dto = CashflowSankeyDto(nodes = nodes, links = links)
        assertEquals(7, maxNodesInAnyLayer(dto)) // reproduce el dataset real reportado

        val capped = capNodesPerLayer(dto, maxPerLayer = 6)
        assertEquals(5, capped.maxNodesInAnyLayerHelper()) // 4 reales + "Otros"

        val otros = capped.nodes.find { it.name == "Otros" }
        assertTrue(otros != null, "debe existir un nodo Otros agrupando las categorías de menor valor")
        // Fees(600k) + Transportation(500k) + Schatzi(400k) + Sin categoría(100k) = 1.600.000
        assertEquals(1600000.0, otros!!.value)

        // Las de mayor valor se mantienen individuales, sin agrupar
        assertTrue(capped.nodes.any { it.name == "Comisión bancaria" })
        assertTrue(capped.nodes.any { it.name == "Seguro Sportage" })
        assertTrue(capped.nodes.any { it.name == "Healthcare" })

        // El total no se pierde en el proceso de agrupar
        val originalExpenseTotal = links.filter { it.source == 2 }.sumOf { it.value }
        val cappedExpenseTotal = capped.links.filter { it.source == capped.nodes.indexOfFirst { n -> n.name == "Flujo de caja" } }.sumOf { it.value }
        assertEquals(originalExpenseTotal, cappedExpenseTotal)
    }

    @Test
    fun testCapNodesPerLayer_leavesSmallDatasetsUntouched() {
        val nodes = listOf(
            SankeyNodeDto(name = "Salario", value = 930000.0, color = "#10A861"),
            SankeyNodeDto(name = "Flujo de caja", value = 930000.0, color = "#9E9E9E"),
            SankeyNodeDto(name = "Comida", value = 500000.0, color = "#EC2222")
        )
        val links = listOf(
            SankeyLinkDto(source = 0, target = 1, value = 930000.0, color = "#10A861"),
            SankeyLinkDto(source = 1, target = 2, value = 500000.0, color = "#EC2222")
        )
        val dto = CashflowSankeyDto(nodes = nodes, links = links)

        val capped = capNodesPerLayer(dto, maxPerLayer = 6)
        assertEquals(dto, capped)
    }

    private fun CashflowSankeyDto.maxNodesInAnyLayerHelper(): Int = maxNodesInAnyLayer(this)
}
