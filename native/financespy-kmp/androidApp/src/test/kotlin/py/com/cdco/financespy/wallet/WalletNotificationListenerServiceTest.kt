package py.com.cdco.financespy.wallet

import org.junit.Assert.assertEquals
import org.junit.Test

class WalletNotificationListenerServiceTest {
    private val sixHoursMs = SeenNotificationPartsStore.DEFAULT_TTL_MILLIS

    @Test
    fun dropsStaleMessagesOlderThanMaxAgeFromMessagingStyleNotifications() {
        val now = 1_000_000_000_000L
        val twoDaysAgo = now - (2 * 24 * 60 * 60 * 1000L)
        val fiveSecondsAgo = now - 5_000L

        val oldSms = "Banco Continental S.A.E.C.A.. informa. TRANS. APROBADA de la tarjeta DINELCO CLASICA 2744 , monto: 44.000-, en: PANADERIA LA NEGRITA SRL."
        val newSms = "Banco Continental S.A.E.C.A.. informa. TRANS. APROBADA de la tarjeta DINELCO CLASICA 2744 , monto: 33.300-, en: SUPERSEIS - SHOP MADERO."

        val parts = extractNotificationParts(
            bigText = "$oldSms\n$newSms",
            text = newSms,
            textLines = listOf(oldSms, newSms),
            messages = listOf(
                NotificationMessagePart(oldSms, twoDaysAgo),
                NotificationMessagePart(newSms, fiveSecondsAgo)
            ),
            nowMillis = now,
            maxAgeMillis = sixHoursMs
        )

        assertEquals(listOf(newSms), parts)
    }

    @Test
    fun fallsBackToBigTextAndTextLinesWhenMessagesIsEmpty() {
        val parts = extractNotificationParts(
            bigText = "Gs. 150.000 con Amex Gold ••2269",
            text = "Gs. 150.000 con Amex Gold ••2269",
            textLines = listOf("extra line"),
            messages = emptyList(),
            nowMillis = 1_000_000L
        )

        assertEquals(listOf("Gs. 150.000 con Amex Gold ••2269", "extra line"), parts)
    }
}
