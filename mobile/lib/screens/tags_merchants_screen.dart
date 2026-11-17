import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tag.dart';
import '../models/merchant.dart';
import '../providers/tags_merchants_provider.dart';
import '../providers/auth_provider.dart';

class TagsMerchantsScreen extends StatefulWidget {
  const TagsMerchantsScreen({super.key});

  @override
  State<TagsMerchantsScreen> createState() => _TagsMerchantsScreenState();
}

class _TagsMerchantsScreenState extends State<TagsMerchantsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<TagsMerchantsProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchAll(accessToken: accessToken);
    }
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
  }

  Future<void> _createTag() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<TagsMerchantsProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.createTag(accessToken: accessToken, name: name.trim());
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to create tag')),
      );
    }
  }

  Future<void> _deleteTag(Tag tag) async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<TagsMerchantsProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.deleteTag(accessToken: accessToken, tagId: tag.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete tag')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<TagsMerchantsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags & Merchants'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tags'),
            Tab(text: 'Merchants'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTag,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && provider.tags.isEmpty && provider.merchants.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTagsList(colorScheme, provider.tags),
                  _buildMerchantsList(colorScheme, provider.merchants),
                ],
              ),
      ),
    );
  }

  Widget _buildTagsList(ColorScheme colorScheme, List<Tag> tags) {
    if (tags.isEmpty) return _buildEmpty(colorScheme, 'No tags yet. Tap + to add one.');

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tags.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final tag = tags[index];
        return Dismissible(
          key: Key('tag_${tag.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            color: colorScheme.errorContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
          ),
          onDismissed: (_) => _deleteTag(tag),
          child: ListTile(
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _parseColor(tag.color, colorScheme.primary),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(tag.name),
          ),
        );
      },
    );
  }

  Widget _buildMerchantsList(ColorScheme colorScheme, List<Merchant> merchants) {
    if (merchants.isEmpty) return _buildEmpty(colorScheme, 'No merchants yet.');

    return ListView.separated(
      itemCount: merchants.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final merchant = merchants[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: Text(
              merchant.name.isNotEmpty ? merchant.name[0].toUpperCase() : '?',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          title: Text(merchant.name),
          subtitle: merchant.type == 'ProviderMerchant' ? const Text('Detected automatically') : null,
        );
      },
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme, String message) {
    return Center(
      child: Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
    );
  }
}
