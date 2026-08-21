package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.components.AppButton

@Composable
fun RulesListScreen(
    viewModel: RulesListViewModel,
    onRuleClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val rules by viewModel.rules.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        AppButton(text = "Nueva regla", onClick = onCreateClick)
        LazyColumn {
            items(rules) { rule ->
                Text(
                    "${rule.name ?: "(sin nombre)"} — ${if (rule.active) "activa" else "inactiva"}",
                    modifier = Modifier.fillMaxWidth().clickable { onRuleClick(rule.id) }
                )
            }
        }
    }
}
