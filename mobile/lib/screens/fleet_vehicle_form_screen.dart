import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_vehicle.dart';
import '../providers/fleet_vehicles_provider.dart';
import '../providers/auth_provider.dart';

class FleetVehicleFormScreen extends StatefulWidget {
  final FleetVehicle? vehicle;

  const FleetVehicleFormScreen({super.key, this.vehicle});

  @override
  State<FleetVehicleFormScreen> createState() => _FleetVehicleFormScreenState();
}

class _FleetVehicleFormScreenState extends State<FleetVehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _notesController;
  late String _status;
  bool _isSaving = false;

  static const _statuses = ['active', 'maintenance', 'inactive'];

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _plateController = TextEditingController(text: vehicle?.plate ?? '');
    _brandController = TextEditingController(text: vehicle?.brand ?? '');
    _modelController = TextEditingController(text: vehicle?.model ?? '');
    _yearController = TextEditingController(text: vehicle?.year?.toString() ?? '');
    _notesController = TextEditingController();
    _status = vehicle?.status ?? 'active';
  }

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final provider = context.read<FleetVehiclesProvider>();
    final accessToken = await authProvider.getValidAccessToken();

    if (accessToken == null || !mounted) {
      setState(() => _isSaving = false);
      return;
    }

    final year = int.tryParse(_yearController.text);

    final result = _isEditing
        ? await provider.updateFleetVehicle(
            accessToken: accessToken,
            vehicleId: widget.vehicle!.id,
            plate: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
            brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
            model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
            year: year,
            status: _status,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          )
        : await provider.createFleetVehicle(
            accessToken: accessToken,
            plate: _plateController.text.trim().isEmpty ? null : _plateController.text.trim(),
            brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
            model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
            year: year,
            status: _status,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result['success'] == true) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error']?.toString() ?? 'Failed to save vehicle')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Vehicle' : 'New Vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _plateController, decoration: const InputDecoration(labelText: 'Plate')),
            const SizedBox(height: 12),
            TextFormField(controller: _brandController, decoration: const InputDecoration(labelText: 'Brand')),
            const SizedBox(height: 12),
            TextFormField(controller: _modelController, decoration: const InputDecoration(labelText: 'Model')),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              decoration: const InputDecoration(labelText: 'Year'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEditing ? 'Save Changes' : 'Create Vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}
