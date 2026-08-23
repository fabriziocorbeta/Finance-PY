package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun RulesListScreen(
    viewModel: RulesListViewModel,
    onRuleClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val rules by viewModel.rules.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                AppButton(
                    text = "Nueva regla",
                    onClick = onCreateClick,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            items(rules) { rule ->
                AppCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onRuleClick(rule.id) }
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = rule.name ?: "(sin nombre)",
                            style = MaterialTheme.typography.titleMedium,
                            color = FinancePyColors.textPrimary()
                        )
                        Text(
                            text = if (rule.active) "activa" else "inactiva",
                            style = MaterialTheme.typography.labelMedium,
                            color = if (rule.active) FinancePyColors.success() else FinancePyColors.textSubdued()
                        )
                    }
                }
            }
        }
    }
}
