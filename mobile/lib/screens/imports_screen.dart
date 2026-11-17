import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/csv_import.dart';
import '../models/account.dart';
import '../providers/imports_provider.dart';
import '../providers/accounts_provider.dart';
import '../providers/auth_provider.dart';

class ImportsScreen extends StatefulWidget {
  const ImportsScreen({super.key});

  @override
  State<ImportsScreen> createState() => _ImportsScreenState();
}

class _ImportsScreenState extends State<ImportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<ImportsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchImports(accessToken: accessToken);
    }
  }

  Future<void> _startNewImport() async {
    final accountsProvider = context.read<AccountsProvider>();
    final accounts = accountsProvider.accounts;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No accounts available to import into.')),
      );
      return;
    }

    final selectedAccount = await showModalBottomSheet<Account>(
      context: context,
      builder: (context) => _AccountPickerSheet(accounts: accounts),
    );

    if (selectedAccount == null || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }

    String csvContent;
    try {
      csvContent = utf8.decode(bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The file does not look like a valid text/CSV file.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final importsProvider = context.read<ImportsProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final createResult = await importsProvider.createImport(
      accessToken: accessToken,
      accountId: selectedAccount.id,
      csvContent: csvContent,
    );

    if (!mounted) return;

    if (createResult['success'] == true) {
      final created = createResult['import'] as CsvImport;
      final message = created.statusDetail.configured
          ? 'Import created and processing started.'
          : 'Import created, but columns couldn\'t be auto-detected -- finish mapping them on the web.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(createResult['error']?.toString() ?? 'Import failed.')),
      );
    }
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'complete':
        return Colors.green.shade700;
      case 'failed':
      case 'revert_failed':
        return colorScheme.error;
      case 'importing':
      case 'reverting':
        return Colors.amber.shade800;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<ImportsProvider>();
    final imports = provider.imports;

    return Scaffold(
      appBar: AppBar(title: const Text('Imports')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isSubmitting ? null : _startNewImport,
        icon: provider.isSubmitting
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file),
        label: const Text('Import CSV'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && imports.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage != null && imports.isEmpty
                ? _buildErrorState(colorScheme, provider.errorMessage!)
                : imports.isEmpty
                    ? _buildEmptyState(colorScheme)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: imports.length,
                        separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                        itemBuilder: (context, index) => _buildItem(colorScheme, imports[index]),
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
            Icon(Icons.upload_file_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Imports Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap "Import CSV" to bring in transactions from a bank export.',
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
            Text('Unable to load imports', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme colorScheme, CsvImport item) {
    final statusColor = _statusColor(item.status, colorScheme);
    final subtitleParts = <String>[item.status];
    if (item.rowsCount != null) subtitleParts.add('${item.rowsCount} rows');
    if (!item.statusDetail.configured) subtitleParts.add('needs mapping on web');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.description_outlined, color: statusColor),
      ),
      title: Text('Import ${item.createdAt.split('T').first}'),
      subtitle: Text(
        subtitleParts.join(' • '),
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      trailing: item.error != null
          ? Icon(Icons.warning_amber_rounded, color: colorScheme.error)
          : null,
    );
  }
}

class _AccountPickerSheet extends StatelessWidget {
  final List<Account> accounts;

  const _AccountPickerSheet({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Import into which account?', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ...accounts.map(
            (account) => ListTile(
              title: Text(account.name),
              subtitle: Text(account.displayAccountType),
              onTap: () => Navigator.pop(context, account),
            ),
          ),
        ],
      ),
    );
  }
}
