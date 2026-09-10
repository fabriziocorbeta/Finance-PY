package py.com.cdco.financespy.screens.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.AccountGroupDto
import py.com.cdco.financespy.api.dto.ClassificationGroupDto
import py.com.cdco.financespy.api.dto.DashboardBalanceSheetDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun BalanceSheetBreakdownCard(
    balanceSheet: DashboardBalanceSheetDto?,
    currency: String = "PYG",
    onAccountClick: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Balance de situación",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )

            val classificationGroups = balanceSheet?.classification_groups ?: emptyList()

            Spacer(modifier = Modifier.height(16.dp))

            classificationGroups.forEachIndexed { idx, cg ->
                if (idx > 0) {
                    Spacer(modifier = Modifier.height(20.dp))
                }
                ClassificationGroupSection(
                    classificationGroup = cg,
                    currency = currency,
                    onAccountClick = onAccountClick
                )
            }
        }
    }
}

@Composable
private fun ClassificationGroupSection(
    classificationGroup: ClassificationGroupDto,
    currency: String,
    onAccountClick: (String) -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = classificationGroup.name,
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = formatMoney(classificationGroup.total, currency),
                style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }

        Spacer(modifier = Modifier.height(8.dp))

        MultiSegmentWeightBar(
            accountGroups = classificationGroup.account_groups,
            modifier = Modifier
                .fillMaxWidth()
                .height(8.dp)
        )

        Spacer(modifier = Modifier.height(12.dp))

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            classificationGroup.account_groups.forEach { group ->
                AccountGroupExpandableItem(
                    accountGroup = group,
                    currency = currency,
                    onAccountClick = onAccountClick
                )
            }
        }
    }
}

@Composable
private fun MultiSegmentWeightBar(
    accountGroups: List<AccountGroupDto>,
    modifier: Modifier = Modifier
) {
    val successColor = FinancePyColors.success()
    val destructiveColor = FinancePyColors.destructive()
    val warningColor = FinancePyColors.warning()
    val primaryColor = FinancePyColors.buttonBgPrimary()
    val borderSecondaryColor = FinancePyColors.borderSecondary()

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(borderSecondaryColor)
    ) {
        Canvas(modifier = Modifier.fillMaxWidth().height(8.dp)) {
            val widthPx = size.width
            val totalWeight = accountGroups.sumOf { it.weight }.let { if (it <= 0) 100.0 else it }

            var currentX = 0f
            accountGroups.forEach { group ->
                val segmentW = ((group.weight / totalWeight) * widthPx).toFloat()
                if (segmentW > 0) {
                    val color = parseColorString(
                        group.color, primaryColor, successColor, destructiveColor, warningColor, primaryColor
                    )
                    drawRoundRect(
                        color = color,
                        topLeft = Offset(currentX, 0f),
                        size = Size(segmentW, size.height),
                        cornerRadius = CornerRadius(2f, 2f)
                    )
                    currentX += segmentW
                }
            }
        }
    }
}

@Composable
private fun AccountGroupExpandableItem(
    accountGroup: AccountGroupDto,
    currency: String,
    onAccountClick: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    val successColor = FinancePyColors.success()
    val destructiveColor = FinancePyColors.destructive()
    val warningColor = FinancePyColors.warning()
    val primaryColor = FinancePyColors.buttonBgPrimary()

    val groupColor = parseColorString(
        accountGroup.color, primaryColor, successColor, destructiveColor, warningColor, primaryColor
    )

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(FinancePyColors.container())
            .padding(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded },
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.weight(1f)
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .background(groupColor, CircleShape)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = accountGroup.name,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.textPrimary()
                )
                if (accountGroup.weight > 0) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = "(${accountGroup.weight}%)",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = formatMoney(accountGroup.total, currency),
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )
                Spacer(modifier = Modifier.width(4.dp))
                Icon(
                    imageVector = if (expanded) Icons.Default.KeyboardArrowUp else Icons.Default.KeyboardArrowDown,
                    contentDescription = null,
                    tint = FinancePyColors.textSecondary(),
                    modifier = Modifier.size(20.dp)
                )
            }
        }

        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp, start = 18.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                accountGroup.accounts.forEach { acc ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onAccountClick(acc.id) }
                            .padding(vertical = 4.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = acc.name,
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textPrimary()
                        )
                        Text(
                            text = formatMoney(acc.balance, acc.currency),
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
            }
        }
    }
}
