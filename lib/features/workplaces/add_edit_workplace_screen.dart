import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/app_database.dart';
import 'providers/add_edit_workplace_provider.dart';

class AddEditWorkplaceScreen extends ConsumerWidget {
  const AddEditWorkplaceScreen({this.workplaceId, super.key});

  final int? workplaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workplaceState = ref.watch(addEditWorkplaceProvider(workplaceId));

    return Scaffold(
      appBar: AppBar(
        title: Text(workplaceId == null ? 'Add Workplace' : 'Edit Workplace'),
      ),
      body: workplaceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (workplace) => _WorkplaceForm(
          initialWorkplace: workplace,
          onSave: ({
            required name,
            required address,
            required latitude,
            required longitude,
            required radiusMeters,
            required isHome,
          }) async {
            await ref
                .read(addEditWorkplaceProvider(workplaceId).notifier)
                .save(
                  name: name,
                  address: address,
                  latitude: latitude,
                  longitude: longitude,
                  radiusMeters: radiusMeters,
                  isHome: isHome,
                );
            if (context.mounted) context.pop();
          },
        ),
      ),
    );
  }
}

typedef _WorkplaceSaveCallback = Future<void> Function({
  required String name,
  required String address,
  required double latitude,
  required double longitude,
  required double radiusMeters,
  required bool isHome,
});

class _WorkplaceForm extends StatefulWidget {
  const _WorkplaceForm({required this.initialWorkplace, required this.onSave});

  final WorkPlace? initialWorkplace;
  final _WorkplaceSaveCallback onSave;

  @override
  State<_WorkplaceForm> createState() => _WorkplaceFormState();
}

class _WorkplaceFormState extends State<_WorkplaceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  late bool _isHome;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final workplace = widget.initialWorkplace;
    _nameController = TextEditingController(text: workplace?.name ?? '');
    _addressController = TextEditingController(text: workplace?.address ?? '');
    _latitudeController = TextEditingController(
      text: workplace != null ? workplace.latitude.toString() : '',
    );
    _longitudeController = TextEditingController(
      text: workplace != null ? workplace.longitude.toString() : '',
    );
    _radiusController = TextEditingController(
      text: workplace != null ? workplace.radiusMeters.toString() : '100',
    );
    _isHome = workplace?.isHome ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        latitude: double.tryParse(_latitudeController.text.trim()) ?? 0.0,
        longitude: double.tryParse(_longitudeController.text.trim()) ?? 0.0,
        radiusMeters: double.tryParse(_radiusController.text.trim()) ?? 100.0,
        isHome: _isHome,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _requiredValidator(String? value) =>
      (value == null || value.trim().isEmpty) ? 'This field is required' : null;

  String? _numberValidator(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    return parsed == null ? 'Enter a valid number' : null;
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
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      textInputAction: TextInputAction.next,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      textInputAction: TextInputAction.next,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                textInputAction: TextInputAction.done,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Geofence radius (m)',
                  prefixIcon: Icon(Icons.my_location),
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as home'),
                value: _isHome,
                onChanged: (value) => setState(() => _isHome = value),
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
