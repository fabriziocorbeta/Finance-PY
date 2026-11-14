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
import kotlin.test.assertFalse
import kotlin.test.assertNull
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
        // Oldest-first: ChatScreen's LazyColumn is a plain (non-reversed) list
        // that auto-scrolls to the last index, so the user message stays at 0
        // and the assistant's reply lands at the end, near the input.
        assertEquals("user", state.messages[0].role)
        assertEquals("assistant", state.messages[1].role)

        // Total network calls should be 2 (initial fetch + 1 poll)
        assertEquals(2, callCount)

        // ChatViewModel now owns a child Job (so its polling coroutine can be
        // cancelled independently when the chat screen is left -- see
        // DisposableEffect in App.kt). That Job stays active until disposed,
        // even once its coroutines finish, so runTest sees it as a leaked
        // child of the test scope unless we dispose it here.
        viewModel.dispose()
    }

    @Test
    fun testSendMessageAppendsNewMessageAndStartsPolling() = scope.runTest {
        var callCount = 0

        val mockConfig = MockEngineConfig()
        mockConfig.dispatcher = dispatcher
        mockConfig.addHandler { request ->
            callCount++
            val responseJson = when {
                // 1: initial refresh() -- one already-answered message, no polling
                callCount == 1 -> """
                {
                  "id": "chat_1", "title": "Chat", "error": null,
                  "messages": [
                    {"id": "msg_1", "type": "user_message", "role": "user", "content": "Old"},
                    {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": "Old reply"}
                  ]
                }
                """.trimIndent()
                // 2: POST send -- server returns the newly created user message
                callCount == 2 -> """
                {"id": "msg_3", "type": "user_message", "role": "user", "content": "New"}
                """.trimIndent()
                // 3: poll fetch -- assistant has now replied
                else -> """
                {
                  "id": "chat_1", "title": "Chat", "error": null,
                  "messages": [
                    {"id": "msg_1", "type": "user_message", "role": "user", "content": "Old"},
                    {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": "Old reply"},
                    {"id": "msg_3", "type": "user_message", "role": "user", "content": "New"},
                    {"id": "msg_4", "type": "assistant_message", "role": "assistant", "content": "New reply"}
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
            install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
        }
        val api = FinancePyApi(httpClient)
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")

        scheduler.runCurrent()
        assertEquals(2, viewModel.state.value.messages.size)

        viewModel.sendMessage("New")
        scheduler.runCurrent()

        // The just-sent message must be appended at the END (oldest-first list,
        // last index = what ChatScreen's auto-scroll targets) -- prepending it
        // at index 0 put brand-new messages at the visual TOP of the chat,
        // away from the input, confirmed live on device.
        var state = viewModel.state.value
        assertEquals(3, state.messages.size)
        assertEquals("msg_3", state.messages[2].id)

        // Polling must have started right away via checkAndPoll reading the
        // list's last element (still a user message) -- advancing past the
        // poll delay should resolve it.
        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()

        state = viewModel.state.value
        assertEquals(4, state.messages.size)
        assertEquals("assistant", state.messages[3].role)
        assertEquals(3, callCount)

        viewModel.dispose()
    }

    // Mirrors ApiClient (expectSuccess = true): a 4xx/5xx throws instead of decoding a DTO.
    private fun apiReplying(handler: (path: String, call: Int) -> Pair<HttpStatusCode, String>): FinancePyApi {
        var calls = 0
        val mockConfig = MockEngineConfig()
        mockConfig.dispatcher = dispatcher
        mockConfig.addHandler { request ->
            calls++
            val (status, body) = handler(request.url.encodedPath, calls)
            respond(content = body, status = status, headers = headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val httpClient = HttpClient(MockEngine(mockConfig)) {
            expectSuccess = true
            install(ContentNegotiation) { json(Json { ignoreUnknownKeys = true }) }
        }
        return FinancePyApi(httpClient)
    }

    private val answeredChat = """
        {"id": "chat_1", "title": "Chat", "error": null, "messages": [
          {"id": "msg_1", "type": "user_message", "role": "user", "content": "Old"},
          {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": "Old reply"}
        ]}
    """.trimIndent()

    private val friendly = "El proveedor de IA no está disponible temporalmente en este momento. Intentá de nuevo en unos minutos."

    @Test
    fun testPollStopsAndShowsChatErrorWhenAssistantFailed() = scope.runTest {
        var fetches = 0
        val api = apiReplying { path, _ ->
            when {
                path.endsWith("/messages") ->
                    HttpStatusCode.Created to """{"id": "msg_3", "type": "user_message", "role": "user", "content": "New"}"""
                ++fetches == 1 -> HttpStatusCode.OK to answeredChat
                // The LLM 503'd: the server deleted the pending reply and stored chat.error.
                else -> HttpStatusCode.OK to """
                    {"id": "chat_1", "title": "Chat", "error": "$friendly", "messages": [
                      {"id": "msg_1", "type": "user_message", "role": "user", "content": "Old"},
                      {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": "Old reply"},
                      {"id": "msg_3", "type": "user_message", "role": "user", "content": "New"}
                    ]}
                """.trimIndent()
            }
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()

        viewModel.sendMessage("New")
        scheduler.runCurrent()
        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()

        var state = viewModel.state.value
        assertEquals(friendly, state.error)
        assertFalse(state.isSending)
        assertEquals("user", state.messages.last().role)
        assertEquals(2, fetches)

        // Polling must have stopped: no more fetches however long we wait.
        scheduler.advanceTimeBy(20_000)
        scheduler.runCurrent()
        state = viewModel.state.value
        assertEquals(2, fetches)
        assertEquals(friendly, state.error)

        viewModel.dispose()
    }

    @Test
    fun testOpeningChatWithFailedTurnShowsErrorWithoutPolling() = scope.runTest {
        var fetches = 0
        val api = apiReplying { _, _ ->
            fetches++
            // Legacy servers stored the raw JSON payload; never show it or technical_message.
            HttpStatusCode.OK to """
                {"id": "chat_1", "title": "Chat",
                 "error": "{\"message\":\"$friendly\",\"technical_message\":\"503 Service Unavailable\"}",
                 "messages": [{"id": "msg_1", "type": "user_message", "role": "user", "content": "Hola"}]}
            """.trimIndent()
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()
        scheduler.advanceTimeBy(10_000)
        scheduler.runCurrent()

        assertEquals(friendly, viewModel.state.value.error)
        assertEquals(1, fetches)

        viewModel.dispose()
    }

    @Test
    fun testRetryClearsErrorAndPollsDespiteStaleChatError() = scope.runTest {
        var fetches = 0
        val failedTurn = """
            {"id": "msg_1", "type": "user_message", "role": "user", "content": "Hola"}
        """.trimIndent()
        val api = apiReplying { path, _ ->
            when {
                path.endsWith("/retry") ->
                    HttpStatusCode.Accepted to """{"message": "Retry initiated", "message_id": "msg_2"}"""
                ++fetches == 1 -> HttpStatusCode.OK to """{"id": "chat_1", "title": "Chat", "error": "$friendly", "messages": [$failedTurn]}"""
                // The retry endpoint leaves chat.error in place while its placeholder is pending.
                fetches == 2 -> HttpStatusCode.OK to """
                    {"id": "chat_1", "title": "Chat", "error": "$friendly", "messages": [$failedTurn,
                      {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": ""}]}
                """.trimIndent()
                // Once the reply is done the error is gone (Chat#retry_last_message! clears it).
                else -> HttpStatusCode.OK to """
                    {"id": "chat_1", "title": "Chat", "error": null, "messages": [$failedTurn,
                      {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": "Listo"}]}
                """.trimIndent()
            }
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()
        assertEquals(friendly, viewModel.state.value.error)

        viewModel.retryMessage()
        scheduler.runCurrent()
        assertNull(viewModel.state.value.error)

        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()
        assertNull(viewModel.state.value.error)
        assertEquals(2, fetches)

        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()
        val state = viewModel.state.value
        assertNull(state.error)
        assertEquals("Listo", state.messages.last().content)
        assertEquals(3, fetches)

        viewModel.dispose()
    }

    @Test
    fun testSendWithAiDisabledShowsFriendlyText() = scope.runTest {
        val api = apiReplying { path, _ ->
            if (path.endsWith("/messages")) {
                HttpStatusCode.Forbidden to """{"error": "feature_disabled", "message": "AI features are not enabled for this user"}"""
            } else {
                HttpStatusCode.OK to answeredChat
            }
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()

        viewModel.sendMessage("Hola")
        scheduler.runCurrent()

        val state = viewModel.state.value
        assertEquals(ChatErrors.FEATURE_DISABLED, state.error)
        assertFalse(state.isSending)

        viewModel.dispose()
    }

    @Test
    fun testSendWhenAssistantBusyShowsFriendlyText() = scope.runTest {
        val api = apiReplying { path, _ ->
            if (path.endsWith("/messages")) HttpStatusCode.ServiceUnavailable to "{}" else HttpStatusCode.OK to answeredChat
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()

        viewModel.sendMessage("Hola")
        scheduler.runCurrent()

        assertEquals(ChatErrors.BUSY, viewModel.state.value.error)

        viewModel.dispose()
    }

    @Test
    fun testPollShowsErrorWhenReplyWasCutShort() = scope.runTest {
        var fetches = 0
        val api = apiReplying { path, _ ->
            when {
                path.endsWith("/messages") ->
                    HttpStatusCode.Created to """{"id": "msg_3", "type": "user_message", "role": "user", "content": "New"}"""
                ++fetches == 1 -> HttpStatusCode.OK to answeredChat
                // Text had streamed when the provider failed: the server keeps the partial reply
                // (status failed, not serialized) and stores chat.error.
                else -> HttpStatusCode.OK to """
                    {"id": "chat_1", "title": "Chat", "error": "$friendly", "messages": [
                      {"id": "msg_1", "type": "user_message", "role": "user", "content": "Old"},
                      {"id": "msg_2", "type": "assistant_message", "role": "assistant", "content": "Old reply"},
                      {"id": "msg_3", "type": "user_message", "role": "user", "content": "New"},
                      {"id": "msg_4", "type": "assistant_message", "role": "assistant", "content": "Tus gastos de"}
                    ]}
                """.trimIndent()
            }
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()

        viewModel.sendMessage("New")
        scheduler.runCurrent()
        scheduler.advanceTimeBy(2500)
        scheduler.runCurrent()
        scheduler.advanceTimeBy(20_000)
        scheduler.runCurrent()

        val state = viewModel.state.value
        assertEquals(friendly, state.error)
        assertEquals("Tus gastos de", state.messages.last().content)
        assertEquals(2, fetches)

        viewModel.dispose()
    }

    @Test
    fun testSendOverDailyQuotaShowsServerReason() = scope.runTest {
        val reason = "Alcanzaste el límite diario de uso de IA de tu familia. Volvé a intentarlo mañana."
        val api = apiReplying { path, _ ->
            if (path.endsWith("/messages")) {
                HttpStatusCode.UnprocessableEntity to """{"error": "Failed to create message", "details": ["$reason"]}"""
            } else {
                HttpStatusCode.OK to answeredChat
            }
        }
        val viewModel = ChatViewModel(scope, api, chatId = "chat_1")
        scheduler.runCurrent()

        viewModel.sendMessage("Hola")
        scheduler.runCurrent()

        assertEquals(reason, viewModel.state.value.error)

        viewModel.dispose()
    }

    @Test
    fun testChatErrorDecoding() {
        assertNull(ChatErrors.fromChatError(null))
        assertNull(ChatErrors.fromChatError("  "))
        assertEquals(friendly, ChatErrors.fromChatError(friendly))
        assertEquals(friendly, ChatErrors.fromChatError("""{"message":"$friendly","technical_message":"boom"}"""))
        assertEquals("Viejo error", ChatErrors.fromChatError("\"Viejo error\""))
        assertEquals(ChatErrors.ASSISTANT_FAILED, ChatErrors.fromChatError("""{"technical_message":"boom"}"""))
        assertEquals(ChatErrors.ASSISTANT_FAILED, ChatErrors.fromChatError("{not json"))
    }
}
