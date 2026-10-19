package py.com.cdco.financespy.theme.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalFinancePyMetrics
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant

// Primitivas compartidas de lista y controles agrupados que resuelven su
// estilo según la variante activa (Material 3 vs iOS HIG Inset Grouped).
@Composable
fun AppSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    trailing: (@Composable () -> Unit)? = null
) {
    val variant = LocalUiVariant.current
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                horizontal = if (variant == UiVariant.IOS) 4.dp else 0.dp,
                vertical = if (variant == UiVariant.IOS) 4.dp else 0.dp
            ),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = when (variant) {
                UiVariant.MATERIAL3 -> MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
                UiVariant.IOS -> MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold)
            },
            color = FinancePyColors.textPrimary()
        )
        trailing?.invoke()
    }
}

@Composable
fun AppGroupedListCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val metrics = LocalFinancePyMetrics.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(metrics.cardCornerRadius))
            .background(FinancePyColors.container()),
        content = content
    )
}

@Composable
fun AppListDivider(
    startInset: Dp = 16.dp
) {
    val variant = LocalUiVariant.current
    HorizontalDivider(
        modifier = Modifier.padding(start = if (variant == UiVariant.IOS) startInset else 0.dp),
        thickness = if (variant == UiVariant.IOS) 0.5.dp else 1.dp,
        color = FinancePyColors.borderSecondary()
    )
}

@Composable
fun <T> AppSegmentedControl(
    options: List<Pair<T, String>>,
    selected: T,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(9.dp))
            .background(FinancePyColors.containerHover())
            .padding(2.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        options.forEach { (value, label) ->
            val isSelected = value == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .then(
                        if (isSelected) {
                            Modifier
                                .shadow(
                                    elevation = 1.dp,
                                    shape = RoundedCornerShape(7.dp),
                                    ambientColor = Color.Black.copy(alpha = 0.08f)
                                )
                                .clip(RoundedCornerShape(7.dp))
                                .background(FinancePyColors.container())
                        } else {
                            Modifier.clip(RoundedCornerShape(7.dp))
                        }
                    )
                    .clickable { onSelect(value) }
                    .padding(vertical = 6.dp, horizontal = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                    ),
                    color = FinancePyColors.textPrimary(),
                    textAlign = TextAlign.Center,
                    maxLines = 1
                )
            }
        }
    }
}
