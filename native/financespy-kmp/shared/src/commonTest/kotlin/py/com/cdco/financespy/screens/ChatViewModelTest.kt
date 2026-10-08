package py.com.cdco.financespy.screens

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockEngineConfig
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
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
    private lateinit var dispatcher: TestDispatcher
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

        val mockConfig = MockEngineConfig()
        // Ktor's default engine dispatcher is a real thread pool, so the response would resume outside
        // the test scheduler and the virtual-time steps below could never observe it. Run the handler
        // on the test dispatcher instead.
        mockConfig.dispatcher = dispatcher
        mockConfig.addHandler { request ->
            callCount++

            // First call happens immediately inside checkAndPoll / pollForAssistantResponse
            // Second call happens after the first 2-second delay
            //
            // Neither mock response includes ai_response_status/
            // ai_response_message -- show.json.jbuilder never serializes
            // those (confirmed by reading it), so a mock that includes them
            // tests a shape the real server never sends. The original
            // version of this mock DID include "ai_response_status":
            // "pending", which is exactly why it never caught the real bug:
            // checkAndPoll relied on that field, so polling never started
            // after sending a message on a real device, even though this
            // test passed.
            val responseJson = if (callCount <= 1) {
                // Return a pending message
                """
                {
                  "id": "chat_1",
                  "title": "Chat",
                  "error": null,
                  "messages": [
                    {
                      "id": "msg_1",
                      "type": "user_message",
                      "role": "user",
                      "content": "Hello"
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
                  "error": null,
                  "messages": [
                    {
                      "id": "msg_1",
                      "type": "user_message",
                      "role": "user",
                      "content": "Hello"
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
        val mockEngine = MockEngine(mockConfig)

        val httpClient = HttpClient(mockEngine) {
            install(ContentNegotiation) {
                json(Json { ignoreUnknownKeys = true })
            }
        }
        val api = FinancePyApi(httpClient)

        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")

        // Let initialization run (it will call refresh() which fetches the first "pending" response)
        // advanceUntilIdle() would also skip the poll's 2 s delay, so the pending state checked below would be gone.
        scheduler.runCurrent()

        var state = viewModel.state.value
        if (state.messages.isEmpty()) {
            scheduler.advanceTimeBy(100)
            scheduler.runCurrent()
            state = viewModel.state.value
        }
        assertTrue(state.messages.isNotEmpty(), "Messages should not be empty")
        // Real server response never includes ai_response_status -- polling
        // must have started from hasPendingReply's ordering check (last
        // message is still a user message) instead.
        assertEquals("user", state.messages[0].role)

        // Fast forward 2.1 seconds. The polling loop should trigger the second request
        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()

        state = viewModel.state.value
        assertEquals(2, state.messages.size)
        assertEquals("assistant", state.messages[0].role) // Reversed order in state
        assertEquals("user", state.messages[1].role)

        // Total network calls should be 2 (initial fetch + 1 poll)
        assertEquals(2, callCount)

        // ChatViewModel now owns a child Job (so its polling coroutine can be
        // cancelled independently when the chat screen is left -- see
        // DisposableEffect in App.kt). That Job stays active until disposed,
        // even once its coroutines finish, so runTest sees it as a leaked
        // child of the test scope unless we dispose it here.
        viewModel.dispose()
    }
}
