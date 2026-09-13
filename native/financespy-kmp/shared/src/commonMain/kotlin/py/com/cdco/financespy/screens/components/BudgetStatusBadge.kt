package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.BudgetCategoryStatus
import py.com.cdco.financespy.theme.FinancePyColors

@Composable
fun BudgetStatusBadge(
    status: BudgetCategoryStatus,
    modifier: Modifier = Modifier
) {
    val (badgeBg, badgeFg, badgeText) = when (status) {
        BudgetCategoryStatus.OVER_BUDGET -> Triple(FinancePyColors.destructive().copy(alpha = 0.15f), FinancePyColors.destructive(), "Presupuesto excedido")
        BudgetCategoryStatus.NEAR_LIMIT -> Triple(FinancePyColors.warning().copy(alpha = 0.15f), FinancePyColors.warning(), "Cerca del límite")
        BudgetCategoryStatus.ON_TRACK -> Triple(FinancePyColors.success().copy(alpha = 0.15f), FinancePyColors.success(), "Correcto")
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(badgeBg)
            .padding(horizontal = 6.dp, vertical = 2.dp)
    ) {
        Text(
            text = badgeText,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
            color = badgeFg,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}
