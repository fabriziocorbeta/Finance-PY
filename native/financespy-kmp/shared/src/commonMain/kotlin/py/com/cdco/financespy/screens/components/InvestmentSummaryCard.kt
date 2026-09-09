package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.HoldingDto
import py.com.cdco.financespy.api.dto.InvestmentSummaryDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun InvestmentSummaryCard(
    investmentSummary: InvestmentSummaryDto?,
    modifier: Modifier = Modifier
) {
    if (investmentSummary == null) return

    val successColor = FinancePyColors.success()
    val destructiveColor = FinancePyColors.destructive()
    val warningColor = FinancePyColors.warning()
    val primaryColor = FinancePyColors.buttonBgPrimary()

    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Inversiones",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )

            Spacer(modifier = Modifier.height(8.dp))

            val portfolioVal = investmentSummary.portfolio_value
            val currency = investmentSummary.currency
            val gains = investmentSummary.unrealized_gains

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Valor de portfolio",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                    Text(
                        text = formatMoney(portfolioVal, currency),
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                        color = FinancePyColors.textPrimary()
                    )
                }

                gains?.let { g ->
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "Rentabilidad total",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        val gainsColor = parseColorString(
                            g.color, successColor, successColor, destructiveColor, warningColor, primaryColor
                        )
                        Text(
                            text = g.percent_formatted ?: formatMoney(g.value, currency),
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = gainsColor
                        )
                    }
                }
            }

            val holdings = investmentSummary.top_holdings
            if (holdings.isNotEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                HorizontalDivider(color = FinancePyColors.borderSecondary())
                Spacer(modifier = Modifier.height(12.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = "Activo",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary(),
                        modifier = Modifier.weight(2f)
                    )
                    Text(
                        text = "Peso",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary(),
                        modifier = Modifier.weight(1f)
                    )
                    Text(
                        text = "Valor",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary(),
                        modifier = Modifier.weight(1.5f)
                    )
                    Text(
                        text = "Rentabilidad",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary(),
                        modifier = Modifier.weight(1.2f)
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    holdings.forEach { holding ->
                        HoldingRow(
                            holding = holding,
                            currency = currency,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor
                        )
                    }
                }
            }

            investmentSummary.activity?.let { act ->
                Spacer(modifier = Modifier.height(16.dp))
                HorizontalDivider(color = FinancePyColors.borderSecondary())
                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    text = "Actividad del período",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.textPrimary()
                )

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(8.dp))
                        .background(FinancePyColors.container())
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Aportaciones",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = formatMoney(act.contributions, currency),
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Retiradas",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = formatMoney(act.withdrawals, currency),
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                    }

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Operaciones",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = "${act.trades_count}",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun HoldingRow(
    holding: HoldingDto,
    currency: String,
    successColor: Color,
    destructiveColor: Color,
    warningColor: Color,
    primaryColor: Color
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(2f)) {
            Text(
                text = holding.ticker,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = holding.name,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
        }

        Text(
            text = "${holding.weight}%",
            style = MaterialTheme.typography.bodySmall,
            color = FinancePyColors.textPrimary(),
            modifier = Modifier.weight(1f)
        )

        Text(
            text = formatMoney(holding.value, currency),
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
            color = FinancePyColors.textPrimary(),
            modifier = Modifier.weight(1.5f)
        )

        holding.return_percent_formatted?.let { ret ->
            val retColor = parseColorString(
                holding.return_color, FinancePyColors.textPrimary(), successColor, destructiveColor, warningColor, primaryColor
            )
            Text(
                text = ret,
                style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                color = retColor,
                modifier = Modifier.weight(1.2f)
            )
        } ?: Spacer(modifier = Modifier.weight(1.2f))
    }
}
