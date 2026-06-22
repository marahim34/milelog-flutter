import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import 'providers/add_edit_vehicle_provider.dart';

class AddEditVehicleScreen extends ConsumerWidget {
  const AddEditVehicleScreen({this.vehicleId, super.key});

  final int? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleState = ref.watch(addEditVehicleProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicleId == null ? 'Add Vehicle' : 'Edit Vehicle'),
      ),
      body: vehicleState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (vehicle) => _VehicleForm(
          initialVehicle: vehicle,
          onSave: ({
            required name,
            required plateNumber,
            required defaultMileageRate,
            required initialOdometer,
            required isDefault,
          }) async {
            await ref.read(addEditVehicleProvider(vehicleId).notifier).save(
                  name: name,
                  plateNumber: plateNumber,
                  defaultMileageRate: defaultMileageRate,
                  initialOdometer: initialOdometer,
                  isDefault: isDefault,
                );
            if (context.mounted) context.pop();
          },
        ),
      ),
    );
  }
}

typedef _VehicleSaveCallback = Future<void> Function({
  required String name,
  required String plateNumber,
  required double defaultMileageRate,
  required double initialOdometer,
  required bool isDefault,
});

class _VehicleForm extends StatefulWidget {
  const _VehicleForm({required this.initialVehicle, required this.onSave});

  final Vehicle? initialVehicle;
  final _VehicleSaveCallback onSave;

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _plateController;
  late final TextEditingController _mileageRateController;
  late final TextEditingController _initialOdometerController;
  late bool _isDefault;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.initialVehicle;
    _nameController = TextEditingController(text: vehicle?.name ?? '');
    _plateController = TextEditingController(text: vehicle?.plateNumber ?? '');
    _mileageRateController = TextEditingController(
      text: vehicle != null && vehicle.defaultMileageRate > 0
          ? vehicle.defaultMileageRate.toString()
          : '',
    );
    _initialOdometerController = TextEditingController(
      text: vehicle != null ? vehicle.initialOdometer.toString() : '0',
    );
    _isDefault = vehicle?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _mileageRateController.dispose();
    _initialOdometerController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        plateNumber: _plateController.text.trim(),
        defaultMileageRate:
            double.tryParse(_mileageRateController.text.trim()) ?? 0.0,
        initialOdometer:
            double.tryParse(_initialOdometerController.text.trim()) ?? 0.0,
        isDefault: _isDefault,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Vehicle name',
                  prefixIcon: Icon(Icons.directions_car),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a vehicle name'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plateController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Plate number',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter a plate number'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mileageRateController,
                textInputAction: TextInputAction.next,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Mileage rate (per km)',
                  helperText: 'Leave blank to use the global default rate',
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _initialOdometerController,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Initial odometer (km)',
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  return parsed == null ? 'Enter a valid number' : null;
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default vehicle'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
