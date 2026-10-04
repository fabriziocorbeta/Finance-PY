package py.com.cdco.financespy.screens

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.FinancePyApi
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class ChatViewModelTest {

    private lateinit var scheduler: TestCoroutineScheduler
    private lateinit var dispatcher: StandardTestDispatcher
    private lateinit var scope: TestScope

    @BeforeTest
    fun setup() {
        scheduler = TestCoroutineScheduler()
        dispatcher = StandardTestDispatcher(scheduler)
        Dispatchers.setMain(dispatcher)
        scope = TestScope(dispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testPollingLogicResolvesPendingMessage() = scope.runTest {
        var callCount = 0

        val mockEngine = MockEngine { request ->
            callCount++

            // First call happens immediately inside checkAndPoll / pollForAssistantResponse
            // Second call happens after the first 2-second delay
            val responseJson = if (callCount <= 1) {
                // Return a pending message
                """
                {
                  "id": "chat_1",
                  "title": "Chat",
                  "messages": [
                    {
                      "id": "msg_1",
                      "type": "user_message",
                      "role": "user",
                      "content": "Hello",
                      "ai_response_status": "pending",
                      "ai_response_message": "Generating..."
                    }
                  ]
                }
                """.trimIndent()
            } else {
                // Return a resolved message
                """
                {
                  "id": "chat_1",
                  "title": "Chat",
                  "messages": [
                    {
                      "id": "msg_1",
                      "type": "user_message",
                      "role": "user",
                      "content": "Hello",
                      "ai_response_status": "completed"
                    },
                    {
                      "id": "msg_2",
                      "type": "assistant_message",
                      "role": "assistant",
                      "content": "Hi there!"
                    }
                  ]
                }
                """.trimIndent()
            }

            respond(
                content = responseJson,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val httpClient = HttpClient(mockEngine) {
            install(ContentNegotiation) {
                json(Json { ignoreUnknownKeys = true })
            }
        }
        val api = FinancePyApi(httpClient)

        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")

        // Let initialization run (it will call refresh() which fetches the first "pending" response)
        scheduler.advanceUntilIdle()

        var state = viewModel.state.value
        if (state.messages.isEmpty()) {
            scheduler.advanceTimeBy(100)
            scheduler.runCurrent()
            state = viewModel.state.value
        }
        assertTrue(state.messages.isNotEmpty(), "Messages should not be empty")
        assertEquals("pending", state.messages[0].ai_response_status)

        // Fast forward 2.1 seconds. The polling loop should trigger the second request
        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()

        state = viewModel.state.value
        assertEquals(2, state.messages.size)
        assertEquals("assistant", state.messages[0].role) // Reversed order in state
        assertEquals("user", state.messages[1].role)
        assertEquals("completed", state.messages[1].ai_response_status)

        // Total network calls should be 2 (initial fetch + 1 poll)
        assertEquals(2, callCount)
    }
}
