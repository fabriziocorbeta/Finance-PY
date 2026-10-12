package py.com.cdco.financespy.screens

import io.ktor.client.HttpClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ProductDto
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ProductsFakeApi : FinancePyApi(HttpClient()) {
    var shouldFail = false
    override suspend fun fetchAllProducts(): List<ProductDto> {
        if (shouldFail) throw Exception("Network Error")
        return listOf(
            ProductDto(id = "1", name = "Product A", buy_price = 100.0, sell_price = 150.0, description = "A", currency = "USD"),
            ProductDto(id = "2", name = "Product B", buy_price = 200.0, sell_price = 250.0, description = "B", currency = "USD")
        )
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class ProductsListViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = ProductsFakeApi()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testInitialStateAndLoadSuccess() = runTest {
        val viewModel = ProductsListViewModel(fakeApi)

        // Initial state
        assertTrue(viewModel.products.value.isEmpty())
        assertFalse(viewModel.isLoading.value)
        assertEquals(null, viewModel.error.value)

        viewModel.refresh()

        // Advance dispatcher to execute coroutine
        testDispatcher.scheduler.advanceUntilIdle()

        // State after load
        assertFalse(viewModel.isLoading.value)
        assertEquals(null, viewModel.error.value)
        assertEquals(2, viewModel.products.value.size)
        assertEquals("Product A", viewModel.products.value[0].name)
    }

    @Test
    fun testLoadError() = runTest {
        fakeApi.shouldFail = true
        val viewModel = ProductsListViewModel(fakeApi)

        viewModel.refresh()
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.isLoading.value)
        assertEquals("Network Error", viewModel.error.value)
        assertTrue(viewModel.products.value.isEmpty())
    }
}
