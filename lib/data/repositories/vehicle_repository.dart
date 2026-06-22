import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Mediates between ViewModels and [VehiclesDao].
///
/// UI and Notifiers must never call VehiclesDao directly — all vehicle reads
/// and writes go through this repository (see CLAUDE.md MVVM rule).
class VehicleRepository {
  VehicleRepository(this._vehiclesDao);

  final VehiclesDao _vehiclesDao;

  Stream<List<Vehicle>> watchAll() => _vehiclesDao.watchAll();

  Future<Vehicle?> getById(int id) => _vehiclesDao.getById(id);

  Future<Vehicle?> getDefault() => _vehiclesDao.getDefault();

  /// Inserts a new vehicle. [lastOdometer] is set equal to [initialOdometer]
  /// since a brand-new vehicle has no trips yet — that is the computed value
  /// (initialOdometer + Σ trip distances) at this point in time, not an
  /// arbitrary direct write (see CLAUDE.md odometer-chain rule).
  Future<int> addVehicle({
    required String name,
    required String plateNumber,
    required double defaultMileageRate,
    required double initialOdometer,
    required bool isDefault,
  }) async {
    if (isDefault) {
      await _vehiclesDao.clearDefault();
    }
    return _vehiclesDao.insertVehicle(
      VehiclesCompanion.insert(
        name: name,
        plateNumber: plateNumber,
        defaultMileageRate: Value(defaultMileageRate),
        initialOdometer: Value(initialOdometer),
        lastOdometer: Value(initialOdometer),
        isDefault: Value(isDefault),
      ),
    );
  }

  /// Updates an existing vehicle. [lastOdometer] is recomputed by preserving
  /// the trip-distance delta already accrued on [existing] and applying it
  /// to the new [initialOdometer] — never set lastOdometer directly without
  /// going through computed logic (see CLAUDE.md odometer-chain rule).
  Future<void> updateVehicleDetails({
    required Vehicle existing,
    required String name,
    required String plateNumber,
    required double defaultMileageRate,
    required double initialOdometer,
    required bool isDefault,
  }) async {
    if (isDefault) {
      await _vehiclesDao.clearDefault();
    }
    final tripDistanceSoFar = existing.lastOdometer - existing.initialOdometer;
    final recomputedLastOdometer = initialOdometer + tripDistanceSoFar;

    await _vehiclesDao.updateVehicle(
      existing
          .copyWith(
            name: name,
            plateNumber: plateNumber,
            defaultMileageRate: defaultMileageRate,
            initialOdometer: initialOdometer,
            lastOdometer: recomputedLastOdometer,
            isDefault: isDefault,
          )
          .toCompanion(true),
    );
  }

  Future<void> deleteVehicle(int id) => _vehiclesDao.deleteVehicle(id);
}
