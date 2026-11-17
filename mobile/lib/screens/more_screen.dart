import 'package:flutter/material.dart';
import 'budget_screen.dart';
import 'calendar_screen.dart';
import 'goals_screen.dart';
import 'investments_screen.dart';
import 'recent_transactions_screen.dart';
import 'recurring_transactions_screen.dart';
import 'rules_screen.dart';
import 'tags_merchants_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: ListView(
        children: [
          _buildMenuItem(
            context: context,
            icon: Icons.calendar_month,
            title: 'Account Calendar',
            subtitle: 'View monthly balance changes by account',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CalendarScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.receipt_long,
            title: 'Recent Transactions',
            subtitle: 'View recent transactions across all accounts',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecentTransactionsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.trending_up,
            title: 'Investments',
            subtitle: 'View holdings across your investment accounts',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvestmentsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.pie_chart_outline,
            title: 'Budget',
            subtitle: 'Track spending against your current budget',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BudgetScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.flag_outlined,
            title: 'Goals',
            subtitle: 'Track progress toward your savings goals',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GoalsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.repeat,
            title: 'Recurring Transactions',
            subtitle: 'View detected subscriptions and recurring bills',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecurringTransactionsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.label_outline,
            title: 'Tags & Merchants',
            subtitle: 'Browse your family\'s tags and merchants',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TagsMerchantsScreen(),
                ),
              );
            },
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          _buildMenuItem(
            context: context,
            icon: Icons.rule_outlined,
            title: 'Rules',
            subtitle: 'View automation rules for transactions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RulesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
