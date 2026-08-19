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
}
