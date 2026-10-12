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
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class ProductFormFakeApi : FinancePyApi(HttpClient()) {
    var shouldFail = false
    var savedProduct: ProductDto? = null
    var deletedProductId: String? = null

    override suspend fun fetchProduct(id: String): ProductDto {
        if (shouldFail) throw Exception("Load Error")
        return ProductDto(id = id, name = "Test Product", sell_price = 100.0, buy_price = 50.0, currency = "usd")
    }

    override suspend fun createProduct(product: ProductDto): ProductDto {
        if (shouldFail) throw Exception("Save Error")
        savedProduct = product
        return product.copy(id = "new_id")
    }

    override suspend fun updateProduct(id: String, product: ProductDto): ProductDto {
        if (shouldFail) throw Exception("Update Error")
        savedProduct = product
        return product
    }

    override suspend fun deleteProduct(id: String) {
        if (shouldFail) throw Exception("Delete Error")
        deletedProductId = id
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class ProductFormViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = ProductFormFakeApi()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        fakeApi.shouldFail = false
        fakeApi.savedProduct = null
        fakeApi.deletedProductId = null
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testLoadExistingProduct() = runTest {
        val viewModel = ProductFormViewModel("prod_1", fakeApi)
        testDispatcher.scheduler.advanceUntilIdle()

        assertFalse(viewModel.isLoading.value)
        assertEquals(null, viewModel.error.value)
        assertNotNull(viewModel.product.value)
        assertEquals("Test Product", viewModel.product.value?.name)
    }

    @Test
    fun testCreateNewProduct() = runTest {
        val viewModel = ProductFormViewModel(null, fakeApi)
        var savedCalled = false

        viewModel.saveProduct(
            name = "New Product",
            sku = "SKU-123",
            category = "Cat",
            supplier = "Sup",
            buyPrice = 10.0,
            sellPrice = 20.0,
            currency = "PYG",
            minStock = 5,
            initialStock = 10,
            description = "Desc",
            onSaved = { savedCalled = true }
        )

        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(savedCalled)
        assertFalse(viewModel.isSaving.value)
        assertEquals("New Product", fakeApi.savedProduct?.name)
        assertEquals("pyg", fakeApi.savedProduct?.currency)
    }

    @Test
    fun testUpdateExistingProduct() = runTest {
        val viewModel = ProductFormViewModel("prod_1", fakeApi)
        testDispatcher.scheduler.advanceUntilIdle()

        var savedCalled = false
        viewModel.saveProduct(
            name = "Updated Product",
            sku = null,
            category = null,
            supplier = null,
            buyPrice = 15.0,
            sellPrice = 25.0,
            currency = "USD",
            minStock = 0,
            initialStock = 0,
            description = null,
            onSaved = { savedCalled = true }
        )

        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(savedCalled)
        assertEquals("Updated Product", fakeApi.savedProduct?.name)
    }

    @Test
    fun testDeleteProduct() = runTest {
        val viewModel = ProductFormViewModel("prod_1", fakeApi)
        testDispatcher.scheduler.advanceUntilIdle()

        var deletedCalled = false
        viewModel.deleteProduct { deletedCalled = true }

        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(deletedCalled)
        assertEquals("prod_1", fakeApi.deletedProductId)
    }
}
