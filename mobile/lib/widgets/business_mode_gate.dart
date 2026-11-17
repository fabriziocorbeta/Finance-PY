import 'package:flutter/material.dart';

/// Shown instead of the generic error state when a PyME-only endpoint
/// (products, sales, purchase orders, fleet vehicles) returns
/// `business_mode_disabled` because the family hasn't turned on business
/// mode -- a 403 from the backend, not a network/auth failure.
class BusinessModeGate extends StatelessWidget {
  final String featureName;

  const BusinessModeGate({super.key, required this.featureName});

  static const errorCode = 'business_mode_disabled';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Business Mode Required', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Turn on business mode in Settings on the web to use $featureName.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
