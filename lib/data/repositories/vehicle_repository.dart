import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../managers/odometer_manager.dart';

/// Mediates between ViewModels and [VehiclesDao].
///
/// UI and Notifiers must never call VehiclesDao directly — all vehicle reads
/// and writes go through this repository (see CLAUDE.md MVVM rule).
class VehicleRepository {
  VehicleRepository(this._vehiclesDao, this._odometerManager);

  final VehiclesDao _vehiclesDao;
  final OdometerManager _odometerManager;

  Stream<List<Vehicle>> watchAll() => _vehiclesDao.watchAll();

  Future<Vehicle?> getById(int id) => _vehiclesDao.getById(id);

  Future<Vehicle?> getDefault() => _vehiclesDao.getDefault();

  Future<Vehicle?> getByPlate(String plate) => _vehiclesDao.getByPlate(plate);

  Future<Vehicle?> getByBluetoothMac(String mac) =>
      _vehiclesDao.getByBluetoothMac(mac);

  /// Inserts a new vehicle. [lastOdometer] is set equal to [initialOdometer]
  /// since a brand-new vehicle has no trips yet — that is the computed value
  /// (initialOdometer + Σ trip distances) at this point in time, not an
  /// arbitrary direct write (see CLAUDE.md odometer-chain rule).
  Future<int> addVehicle({
    required String name,
    required String plateNumber,
    required double initialOdometer,
    required bool isDefault,
    String? bluetoothMac,
    bool bluetoothAutoStart = true,
  }) async {
    if (isDefault) {
      await _vehiclesDao.clearDefault();
    }
    return _vehiclesDao.insertVehicle(
      VehiclesCompanion.insert(
        name: name,
        plateNumber: plateNumber,
        initialOdometer: Value(initialOdometer),
        lastOdometer: Value(initialOdometer),
        isDefault: Value(isDefault),
        bluetoothMac: Value(bluetoothMac),
        bluetoothAutoStart: Value(bluetoothAutoStart),
      ),
    );
  }

  /// Updates an existing vehicle, then asks [OdometerManager] to recompute
  /// lastOdometer from initialOdometer + Σ trip distances — never set it
  /// directly from a delta (see CLAUDE.md odometer-chain rule).
  Future<void> updateVehicleDetails({
    required Vehicle existing,
    required String name,
    required String plateNumber,
    required double initialOdometer,
    required bool isDefault,
    String? bluetoothMac,
    bool bluetoothAutoStart = true,
  }) async {
    if (isDefault) {
      await _vehiclesDao.clearDefault();
    }

    await _vehiclesDao.updateVehicle(
      existing
          .copyWith(
            name: name,
            plateNumber: plateNumber,
            initialOdometer: initialOdometer,
            isDefault: isDefault,
            bluetoothMac: Value(bluetoothMac),
            bluetoothAutoStart: bluetoothAutoStart,
          )
          .toCompanion(true),
    );

    await _odometerManager.correctOdometerChain(existing.id);
  }

  Future<void> deleteVehicle(int id) => _vehiclesDao.deleteVehicle(id);

  /// Manually corrects a vehicle's current odometer reading (Settings →
  /// Odometer). See [OdometerManager.setOdometerReading].
  Future<void> setOdometerReading(int vehicleId, double reading) =>
      _odometerManager.setOdometerReading(vehicleId, reading);
}
