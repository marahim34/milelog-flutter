import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import 'providers/add_edit_workplace_provider.dart';

class AddEditWorkplaceScreen extends ConsumerWidget {
  const AddEditWorkplaceScreen({this.workplaceId, super.key});

  final int? workplaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final workplaceState = ref.watch(addEditWorkplaceProvider(workplaceId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
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
            await ref.read(addEditWorkplaceProvider(workplaceId).notifier).save(
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
  bool _isLocating = false;
  String? _locationError;

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

  Future<void> _handleUseCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationError = 'Turn on location services and try again.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() =>
            _locationError = 'Location permission is needed to fill this in automatically.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _locationError = "Couldn't get your current location. Try again.");
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
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
    final colors = AppColors.of(context);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.space20,
          AppTheme.space20,
          AppTheme.space20,
          AppTheme.space20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('DETAILS'),
              const SizedBox(height: AppTheme.space8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppTheme.space16),
              TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: _requiredValidator,
              ),
              const SizedBox(height: AppTheme.space20),
              const _SectionLabel('COORDINATES'),
              const SizedBox(height: AppTheme.space8),
              OutlinedButton.icon(
                onPressed: _isLocating ? null : _handleUseCurrentLocation,
                icon: _isLocating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accent,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_isLocating ? 'Locating…' : 'Use my current location'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.space14),
                  side: BorderSide(color: colors.border),
                ),
              ),
              if (_locationError != null) ...[
                const SizedBox(height: AppTheme.space8),
                Text(
                  _locationError!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.danger),
                ),
              ],
              const SizedBox(height: AppTheme.space16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitudeController,
                      textInputAction: TextInputAction.next,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: _numberValidator,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space16),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      textInputAction: TextInputAction.next,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: _numberValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space20),
              const _SectionLabel('GEOFENCE'),
              const SizedBox(height: AppTheme.space8),
              TextFormField(
                controller: _radiusController,
                textInputAction: TextInputAction.done,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Geofence radius (m)',
                  prefixIcon: Icon(Icons.radar),
                ),
                validator: _numberValidator,
              ),
              const SizedBox(height: AppTheme.space16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as home'),
                value: _isHome,
                onChanged: (value) => setState(() => _isHome = value),
              ),
              const SizedBox(height: AppTheme.space24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
    );
  }
}
