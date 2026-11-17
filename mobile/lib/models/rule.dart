class RuleCondition {
  final String conditionType;
  final String operator;
  final String? value;

  RuleCondition({required this.conditionType, required this.operator, this.value});

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      conditionType: json['condition_type'] as String? ?? '',
      operator: json['operator'] as String? ?? '',
      value: json['value']?.toString(),
    );
  }
}

class RuleAction {
  final String actionType;
  final String? value;

  RuleAction({required this.actionType, this.value});

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(
      actionType: json['action_type'] as String? ?? '',
      value: json['value']?.toString(),
    );
  }
}

class Rule {
  final String id;
  final String name;
  final String resourceType;
  final bool active;
  final List<RuleCondition> conditions;
  final List<RuleAction> actions;

  Rule({
    required this.id,
    required this.name,
    required this.resourceType,
    required this.active,
    required this.conditions,
    required this.actions,
  });

  factory Rule.fromJson(Map<String, dynamic> json) {
    final conditionsJson = json['conditions'] as List<dynamic>? ?? [];
    final actionsJson = json['actions'] as List<dynamic>? ?? [];
    return Rule(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      resourceType: json['resource_type'] as String? ?? 'transaction',
      active: json['active'] as bool? ?? true,
      conditions: conditionsJson.map((c) => RuleCondition.fromJson(c as Map<String, dynamic>)).toList(),
      actions: actionsJson.map((a) => RuleAction.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }
}
