import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/goal.dart';
import '../providers/goals_provider.dart';
import '../providers/auth_provider.dart';
import 'goal_form_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGoals();
    });
  }

  Future<void> _loadGoals() async {
    final authProvider = context.read<AuthProvider>();
    final goalsProvider = context.read<GoalsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await goalsProvider.fetchGoals(accessToken: accessToken);
    }
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  (Color, String) _statusDisplay(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'on_track':
        return (Colors.green.shade700, 'On track');
      case 'behind':
        return (colorScheme.error, 'Behind');
      case 'reached':
        return (colorScheme.primary, 'Reached');
      case 'completed':
        return (colorScheme.primary, 'Completed');
      case 'paused':
        return (colorScheme.onSurfaceVariant, 'Paused');
      case 'archived':
        return (colorScheme.onSurfaceVariant, 'Archived');
      default:
        return (colorScheme.onSurfaceVariant, 'No target date');
    }
  }

  Future<void> _openForm({Goal? goal}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => GoalFormScreen(goal: goal)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(goal == null ? 'Goal created.' : 'Goal updated.')),
      );
    }
  }

  Future<void> _archiveGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Goal'),
        content: Text('Archive "${goal.name}"? You can still see it on the web.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<GoalsProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.archiveGoal(accessToken: accessToken, goalId: goal.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to archive goal')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final goalsProvider = context.watch<GoalsProvider>();
    final goals = goalsProvider.goals;

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _loadGoals,
        child: goalsProvider.isLoading && goals.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : goalsProvider.errorMessage != null && goals.isEmpty
                ? _buildErrorState(colorScheme, goalsProvider.errorMessage!)
                : goals.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: goals.length,
                        itemBuilder: (context, index) => _buildGoalCard(colorScheme, goals[index]),
                      ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Goals Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Set up a savings goal on the web to track it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colorScheme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('Unable to load goals', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadGoals, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(ColorScheme colorScheme, Goal goal) {
    final currencyFormat = NumberFormat.currency(symbol: '${goal.currency} ', decimalDigits: 2);
    final color = _parseColor(goal.color, colorScheme.primary);
    final (statusColor, statusLabel) = _statusDisplay(goal.status, colorScheme);
    final progress = (goal.progressPercent.clamp(0, 100) / 100).toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openForm(goal: goal),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.flag, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  goal.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colorScheme.onSurfaceVariant, size: 18),
                onSelected: (value) {
                  if (value == 'archive') _archiveGoal(goal);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceDim,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currencyFormat.format(goal.currentBalance)} of ${currencyFormat.format(goal.targetAmount)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              Text(
                '${goal.progressPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Target: ${goal.targetDate}',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
