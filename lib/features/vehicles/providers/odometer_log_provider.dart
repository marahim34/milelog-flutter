import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';

class OdometerLogState {
  const OdometerLogState({required this.vehicle, required this.readings});

  final Vehicle vehicle;

  /// Newest first.
  final List<OdometerReading> readings;
}

/// ViewModel for [OdometerLogScreen]. UI never talks to
/// OdometerReadingRepository or VehicleRepository directly (see CLAUDE.md
/// MVVM rule).
class OdometerLogNotifier
    extends AutoDisposeFamilyAsyncNotifier<OdometerLogState, int> {
  @override
  Future<OdometerLogState> build(int vehicleId) async {
    final vehicleRepository = ref.watch(vehicleRepositoryProvider);
    final vehicle = await vehicleRepository.getById(vehicleId);
    if (vehicle == null) {
      throw StateError('Vehicle $vehicleId not found');
    }

    final readingRepository = ref.watch(odometerReadingRepositoryProvider);
    final readings =
        await readingRepository.getAllForVehicle(vehicle.plateNumber);
    return OdometerLogState(
      vehicle: vehicle,
      readings: readings.reversed.toList(),
    );
  }

  Future<void> addReading(double readingKm) async {
    final current = state.value;
    if (current == null) return;

    final readingRepository = ref.read(odometerReadingRepositoryProvider);
    await readingRepository.addReading(
      vehicleId: current.vehicle.id,
      vehicleNumber: current.vehicle.plateNumber,
      readingKm: readingKm,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    ref.invalidateSelf();
    await future;
  }
}

final odometerLogProvider = AsyncNotifierProvider.autoDispose
    .family<OdometerLogNotifier, OdometerLogState, int>(
  OdometerLogNotifier.new,
);
