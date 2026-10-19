package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "accounts")
data class AccountEntity(
    @PrimaryKey val id: String,
    val name: String,
    val balanceCents: Long,
    val cashBalanceCents: Long,
    val currency: String,
    val classification: String,
    val accountType: String,
    val subtype: String?,
    val status: String,
    val updatedAt: String,
    // Últimos 4 dígitos de la tarjeta física. Es lo único estable para mapear
    // una notificación del banco a esta cuenta: el nombre lo elige el usuario
    // y varias tarjetas del mismo emisor lo comparten.
    val cardIdentifier: String? = null,
    val institutionName: String? = null
)
