package py.com.cdco.financespy.auth

import kotlin.random.Random

class PkceGenerator {
    fun generateVerifier(): String {
        val bytes = Random.Default.nextBytes(64)
        return base64UrlEncode(bytes).take(128)
    }

    fun challengeFor(verifier: String): String {
        val digest = sha256(verifier.encodeToByteArray())
        return base64UrlEncode(digest)
    }

    private fun base64UrlEncode(bytes: ByteArray): String {
        val table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        val sb = StringBuilder()
        var i = 0
        while (i < bytes.size) {
            val b0 = bytes[i].toInt() and 0xFF
            val b1 = if (i + 1 < bytes.size) bytes[i + 1].toInt() and 0xFF else 0
            val b2 = if (i + 2 < bytes.size) bytes[i + 2].toInt() and 0xFF else 0
            sb.append(table[b0 shr 2])
            sb.append(table[((b0 and 0x03) shl 4) or (b1 shr 4)])
            if (i + 1 < bytes.size) sb.append(table[((b1 and 0x0F) shl 2) or (b2 shr 6)])
            if (i + 2 < bytes.size) sb.append(table[b2 and 0x3F])
            i += 3
        }
        return sb.toString()
    }
}

expect fun sha256(input: ByteArray): ByteArray
