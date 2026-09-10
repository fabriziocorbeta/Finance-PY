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
import py.com.cdco.financespy.api.dto.RuleRegistryDto
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard

/**
 * One-line human-readable summary of a rule's (single) condition/action, using the registry
 * for label lookups. RuleEntity only ever carries one condition and one action (see
 * SyncEngine.toEntityOrNull) - a rule whose top-level condition is a compound/group condition
 * is flattened to conditionType == "compound" with the sub-conditions dropped, so that case is
 * called out explicitly rather than rendered as a nonsensical raw-string sentence.
 */
private fun ruleEntitySummary(rule: RuleEntity, registry: RuleRegistryDto?): String {
    val conditionText = if (rule.conditionType == "compound") {
        "Condición compuesta"
    } else {
        val filter = registry?.filters?.firstOrNull { it.key == rule.conditionType }
        val filterLabel = filter?.label ?: rule.conditionType
        val operatorLabel = filter?.operators?.firstOrNull { it.getOrNull(0) == rule.conditionOperator }?.getOrNull(1)
            ?: rule.conditionOperator
        val valueLabel = filter?.options?.firstOrNull { it.getOrNull(0) == rule.conditionValue }?.getOrNull(1)
            ?: rule.conditionValue
        listOf(filterLabel, operatorLabel, valueLabel).filter { it.isNotBlank() }.joinToString(" ")
    }
    val executor = registry?.executors?.firstOrNull { it.key == rule.actionType }
    val executorLabel = executor?.label ?: rule.actionType
    val actionText = if (executor?.type == "function") {
        executorLabel
    } else {
        val valueLabel = executor?.options?.firstOrNull { it.getOrNull(0) == rule.actionValue }?.getOrNull(1)
            ?: rule.actionValue
        if (valueLabel.isNotBlank()) "$executorLabel: $valueLabel" else executorLabel
    }
    return "Si $conditionText → $actionText"
}

@Composable
fun RulesListScreen(
    viewModel: RulesListViewModel,
    onRuleClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val rules by viewModel.rules.collectAsState()
    val registry by viewModel.registry.collectAsState()

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
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
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
                        Text(
                            text = ruleEntitySummary(rule, registry),
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
            }
        }
    }
}
