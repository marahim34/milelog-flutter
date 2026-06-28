import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';

/// ViewModel for [AddEditVehicleScreen]. The family argument is the vehicle
/// id being edited, or null when adding a new vehicle. UI never talks to
/// VehicleRepository or VehiclesDao directly (see CLAUDE.md MVVM rule).
class AddEditVehicleNotifier
    extends AutoDisposeFamilyAsyncNotifier<Vehicle?, int?> {
  @override
  Future<Vehicle?> build(int? vehicleId) async {
    if (vehicleId == null) return null;
    final repository = ref.watch(vehicleRepositoryProvider);
    return repository.getById(vehicleId);
  }

  Future<void> save({
    required String name,
    required String plateNumber,
    required double initialOdometer,
    required bool isDefault,
    String? bluetoothMac,
    bool bluetoothAutoStart = true,
  }) async {
    final repository = ref.read(vehicleRepositoryProvider);
    final existing = state.value;

    if (existing == null) {
      await repository.addVehicle(
        name: name,
        plateNumber: plateNumber,
        initialOdometer: initialOdometer,
        isDefault: isDefault,
        bluetoothMac: bluetoothMac,
        bluetoothAutoStart: bluetoothAutoStart,
      );
    } else {
      await repository.updateVehicleDetails(
        existing: existing,
        name: name,
        plateNumber: plateNumber,
        initialOdometer: initialOdometer,
        isDefault: isDefault,
        bluetoothMac: bluetoothMac,
        bluetoothAutoStart: bluetoothAutoStart,
      );
    }
  }
}

final addEditVehicleProvider = AsyncNotifierProvider.autoDispose
    .family<AddEditVehicleNotifier, Vehicle?, int?>(AddEditVehicleNotifier.new);
