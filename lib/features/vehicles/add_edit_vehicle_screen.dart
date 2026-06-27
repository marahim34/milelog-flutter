import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/services/bluetooth_service.dart';
import 'providers/add_edit_vehicle_provider.dart';

class AddEditVehicleScreen extends ConsumerWidget {
  const AddEditVehicleScreen({this.vehicleId, super.key});

  final int? vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final vehicleState = ref.watch(addEditVehicleProvider(vehicleId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
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
            required bluetoothMac,
            required bluetoothAutoStart,
          }) async {
            await ref.read(addEditVehicleProvider(vehicleId).notifier).save(
                  name: name,
                  plateNumber: plateNumber,
                  defaultMileageRate: defaultMileageRate,
                  initialOdometer: initialOdometer,
                  isDefault: isDefault,
                  bluetoothMac: bluetoothMac,
                  bluetoothAutoStart: bluetoothAutoStart,
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
  required String? bluetoothMac,
  required bool bluetoothAutoStart,
});

class _VehicleForm extends ConsumerStatefulWidget {
  const _VehicleForm({required this.initialVehicle, required this.onSave});

  final Vehicle? initialVehicle;
  final _VehicleSaveCallback onSave;

  @override
  ConsumerState<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<_VehicleForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _plateController;
  late final TextEditingController _mileageRateController;
  late final TextEditingController _initialOdometerController;
  late bool _isDefault;
  bool _isSaving = false;

  String? _bluetoothMac;
  String? _bluetoothDeviceName;
  late bool _bluetoothAutoStart;
  bool _resolvingDeviceName = false;

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
    _bluetoothMac = vehicle?.bluetoothMac;
    _bluetoothAutoStart = vehicle?.bluetoothAutoStart ?? true;
    if (_bluetoothMac != null) _resolveDeviceName();
  }

  Future<void> _resolveDeviceName() async {
    setState(() => _resolvingDeviceName = true);
    try {
      final hasPermission = await BluetoothService.hasPermission();
      if (!hasPermission) return;
      final devices = await BluetoothService.getBondedDevices();
      for (final device in devices) {
        if (device.address == _bluetoothMac) {
          if (mounted) setState(() => _bluetoothDeviceName = device.name);
          break;
        }
      }
    } finally {
      if (mounted) setState(() => _resolvingDeviceName = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _mileageRateController.dispose();
    _initialOdometerController.dispose();
    super.dispose();
  }

  Future<void> _handlePairDevice() async {
    var status = await Permission.bluetoothConnect.status;
    if (status.isDenied) {
      status = await Permission.bluetoothConnect.request();
    }
    if (!mounted) return;

    if (status.isPermanentlyDenied) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bluetooth permission needed'),
          content: const Text(
            'To pair a vehicle, allow Bluetooth access in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (shouldOpenSettings ?? false) await openAppSettings();
      return;
    }

    if (!status.isGranted) return;

    final devices = await BluetoothService.getBondedDevices();
    if (!mounted) return;

    final selected = await showModalBottomSheet<_DevicePick>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => _DevicePickerSheet(devices: devices),
    );

    if (selected == null) return;
    setState(() {
      _bluetoothMac = selected.address;
      _bluetoothDeviceName = selected.name;
    });
  }

  void _handleForgetDevice() {
    setState(() {
      _bluetoothMac = null;
      _bluetoothDeviceName = null;
    });
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
        bluetoothMac: _bluetoothMac,
        bluetoothAutoStart: _bluetoothAutoStart,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPaired = _bluetoothMac != null;
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
              const _SectionLabel('VEHICLE DETAILS'),
              const SizedBox(height: AppTheme.space8),
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
              const SizedBox(height: AppTheme.space16),
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
              const SizedBox(height: AppTheme.space20),
              const _SectionLabel('MILEAGE'),
              const SizedBox(height: AppTheme.space8),
              TextFormField(
                controller: _mileageRateController,
                textInputAction: TextInputAction.next,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Mileage rate (per km)',
                  helperText: 'Applies to business trips only. Leave blank '
                      'to use the global default rate.',
                  helperMaxLines: 2,
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: AppTheme.space16),
              TextFormField(
                controller: _initialOdometerController,
                textInputAction: TextInputAction.done,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Initial odometer (km)',
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  return parsed == null ? 'Enter a valid number' : null;
                },
              ),
              const SizedBox(height: AppTheme.space16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set as default vehicle'),
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
              ),
              const SizedBox(height: AppTheme.space20),
              const _SectionLabel('BLUETOOTH'),
              const SizedBox(height: AppTheme.space8),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16,
                        vertical: AppTheme.space14,
                      ),
                      leading: Icon(Icons.bluetooth, color: colors.accent),
                      title: Text(isPaired
                          ? (_bluetoothDeviceName ?? _bluetoothMac!)
                          : 'No paired device'),
                      subtitle: Text(
                        isPaired
                            ? _bluetoothMac!
                            : 'Pair a Bluetooth device to auto-start trips',
                      ),
                      trailing: _resolvingDeviceName
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : isPaired
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Forget device',
                                  onPressed: _handleForgetDevice,
                                )
                              : Icon(Icons.chevron_right,
                                  color: colors.textDimmer),
                      onTap: _handlePairDevice,
                    ),
                    if (isPaired)
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space16,
                          vertical: AppTheme.space14,
                        ),
                        title: const Text('Auto-start trip on connect'),
                        subtitle: const Text(
                          'Starts tracking when this device connects, '
                          'pauses on disconnect',
                        ),
                        value: _bluetoothAutoStart,
                        onChanged: (value) =>
                            setState(() => _bluetoothAutoStart = value),
                      ),
                  ],
                ),
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

class _DevicePick {
  const _DevicePick({required this.name, required this.address});

  final String name;
  final String address;
}

class _DevicePickerSheet extends StatelessWidget {
  const _DevicePickerSheet({required this.devices});

  final List<BondedDevice> devices;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space20,
                AppTheme.space10,
                AppTheme.space20,
                AppTheme.space10,
              ),
              child: Text('Paired devices',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space20,
                  0,
                  AppTheme.space20,
                  AppTheme.space20,
                ),
                child: Text(
                  'No paired devices found. Pair your vehicle\'s Bluetooth '
                  'in Android Settings first, then come back here.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.textDim),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: Icon(Icons.bluetooth, color: colors.accent),
                      title: Text(device.name),
                      subtitle: Text(device.address),
                      onTap: () => Navigator.of(context).pop(
                        _DevicePick(name: device.name, address: device.address),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
