package py.com.cdco.financespy.auth

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PkceGeneratorTest {
    @Test
    fun verifierIsUrlSafeAndWithinLength() {
        val verifier = PkceGenerator().generateVerifier()
        assertTrue(verifier.length in 43..128)
        assertTrue(verifier.all { it.isLetterOrDigit() || it == '-' || it == '_' })
    }

    @Test
    fun sameVerifierProducesSameChallenge() {
        val generator = PkceGenerator()
        val verifier = generator.generateVerifier()
        val challenge1 = generator.challengeFor(verifier)
        val challenge2 = generator.challengeFor(verifier)
        assertEquals(challenge1, challenge2)
    }

    @Test
    fun differentVerifiersProduceDifferentChallenges() {
        val generator = PkceGenerator()
        val challengeA = generator.challengeFor(generator.generateVerifier())
        val challengeB = generator.challengeFor(generator.generateVerifier())
        assertTrue(challengeA != challengeB)
    }

    @Test
    fun stateIsUrlSafeAndAtLeast128Bits() {
        val state = PkceGenerator().generateState()
        assertTrue(state.all { it.isLetterOrDigit() || it == '-' || it == '_' })
        // base64url with no padding: 4 chars per 3 bytes, so ceil(16 bytes * 4/3)
        // is the minimum length that can encode >=128 bits (16 bytes).
        assertTrue(state.length >= 22)
    }

    @Test
    fun differentCallsProduceDifferentStates() {
        val generator = PkceGenerator()
        val stateA = generator.generateState()
        val stateB = generator.generateState()
        assertTrue(stateA != stateB)
    }
}
