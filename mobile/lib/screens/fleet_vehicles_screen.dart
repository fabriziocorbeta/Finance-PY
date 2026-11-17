import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_vehicle.dart';
import '../providers/fleet_vehicles_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/business_mode_gate.dart';
import 'fleet_vehicle_form_screen.dart';

class FleetVehiclesScreen extends StatefulWidget {
  const FleetVehiclesScreen({super.key});

  @override
  State<FleetVehiclesScreen> createState() => _FleetVehiclesScreenState();
}

class _FleetVehiclesScreenState extends State<FleetVehiclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final authProvider = context.read<AuthProvider>();
    final provider = context.read<FleetVehiclesProvider>();

    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken != null) {
      await provider.fetchFleetVehicles(accessToken: accessToken);
    }
  }

  Color _statusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'active':
        return Colors.green.shade700;
      case 'maintenance':
        return Colors.amber.shade800;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  Future<void> _openForm({FleetVehicle? vehicle}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => FleetVehicleFormScreen(vehicle: vehicle)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vehicle == null ? 'Vehicle created.' : 'Vehicle updated.')),
      );
    }
  }

  Future<void> _deleteVehicle(FleetVehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Delete "${vehicle.displayName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<FleetVehiclesProvider>();
    final accessToken = await authProvider.getValidAccessToken();
    if (accessToken == null || !mounted) return;

    final result = await provider.deleteFleetVehicle(accessToken: accessToken, vehicleId: vehicle.id);
    if (!mounted) return;
    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete vehicle')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<FleetVehiclesProvider>();
    final vehicles = provider.vehicles;

    return Scaffold(
      appBar: AppBar(title: const Text('Fleet Vehicles')),
      floatingActionButton: provider.errorMessage == BusinessModeGate.errorCode
          ? null
          : FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: provider.isLoading && vehicles.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.errorMessage == BusinessModeGate.errorCode
                ? const BusinessModeGate(featureName: 'Fleet Vehicles')
                : provider.errorMessage != null && vehicles.isEmpty
                    ? _buildErrorState(colorScheme, provider.errorMessage!)
                    : vehicles.isEmpty
                        ? _buildEmptyState(colorScheme)
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: vehicles.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: colorScheme.outlineVariant),
                            itemBuilder: (context, index) => _buildItem(colorScheme, vehicles[index]),
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
            Icon(Icons.local_shipping_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No Fleet Vehicles Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Vehicles and their fuel logs will show up here.',
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
            Text('Unable to load fleet vehicles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(ColorScheme colorScheme, FleetVehicle vehicle) {
    final statusColor = _statusColor(vehicle.status, colorScheme);
    final subtitleParts = <String>[];
    if (vehicle.plate != null) subtitleParts.add(vehicle.plate!);
    if (vehicle.year != null) subtitleParts.add(vehicle.year.toString());
    if (vehicle.averageFuelEfficiency != null) {
      subtitleParts.add('${vehicle.averageFuelEfficiency!.toStringAsFixed(1)} km/L');
    }

    return Dismissible(
      key: Key('vehicle_${vehicle.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _deleteVehicle(vehicle);
        return false;
      },
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: ListTile(
        onTap: () => _openForm(vehicle: vehicle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_shipping_outlined, color: statusColor),
        ),
        title: Text(
          vehicle.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitleParts.join(' • '),
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            vehicle.status,
            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
