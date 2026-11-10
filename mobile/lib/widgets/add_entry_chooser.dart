import 'package:flutter/material.dart';
import '../models/account.dart';
import '../screens/transaction_form_screen.dart';
import '../screens/transfer_form_screen.dart';

/// Shows a small chooser between "New transaction" and "New transfer", then
/// opens the corresponding form sheet. Returns the same `Future<bool?>`
/// contract the two existing call sites already expect from
/// `showModalBottomSheet(... TransactionFormScreen ...)`.
Future<bool?> showAddEntryChooser(BuildContext context, {required Account account}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('New transaction'),
            onTap: () => Navigator.pop(context, 'transaction'),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('New transfer'),
            onTap: () => Navigator.pop(context, 'transfer'),
          ),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return null;

  if (choice == 'transaction') {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionFormScreen(account: account),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => TransferFormScreen(initialFromAccount: account),
  );
}
