import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';

/// ViewModel for [VehiclesScreen]. UI never talks to VehicleRepository or
/// VehiclesDao directly (see CLAUDE.md MVVM rule).
class VehiclesListNotifier extends StreamNotifier<List<Vehicle>> {
  @override
  Stream<List<Vehicle>> build() {
    final repository = ref.watch(vehicleRepositoryProvider);
    return repository.watchAll();
  }

  Future<void> deleteVehicle(int id) async {
    final repository = ref.read(vehicleRepositoryProvider);
    await repository.deleteVehicle(id);
  }
}

final vehiclesListProvider =
    StreamNotifierProvider<VehiclesListNotifier, List<Vehicle>>(
  VehiclesListNotifier.new,
);
