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
    if (tags.isEmpty) return _buildEmpty(colorScheme, 'No tags yet.');

    return ListView.separated(
      itemCount: tags.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final tag = tags[index];
        return ListTile(
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _parseColor(tag.color, colorScheme.primary),
              shape: BoxShape.circle,
            ),
          ),
          title: Text(tag.name),
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
