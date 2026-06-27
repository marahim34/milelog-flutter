import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Recomputes [Vehicle.lastOdometer] from scratch — it is a derived value
/// (initialOdometer + Σ completed-trip distances for that vehicle), never
/// written directly. See CLAUDE.md's odometer-chain rule.
class OdometerManager {
  OdometerManager(this._vehiclesDao, this._tripsDao);

  final VehiclesDao _vehiclesDao;
  final TripsDao _tripsDao;

  Future<void> correctOdometerChain(int vehicleId) async {
    final vehicle = await _vehiclesDao.getById(vehicleId);
    if (vehicle == null) return;

    final tripDistance =
        await _tripsDao.sumDistanceForVehicle(vehicle.plateNumber);
    await _vehiclesDao.updateLastOdometer(
      vehicleId,
      vehicle.initialOdometer + tripDistance,
    );
  }

  /// A manual correction to the vehicle's *current* reading (e.g. the user
  /// checked the dash and it doesn't match) — shifts [Vehicle.initialOdometer]
  /// by the same amount so the chain re-derives back to [reading] rather
  /// than writing [Vehicle.lastOdometer] directly, which [correctOdometerChain]
  /// would just overwrite on the next trip anyway.
  Future<void> setOdometerReading(int vehicleId, double reading) async {
    final vehicle = await _vehiclesDao.getById(vehicleId);
    if (vehicle == null) return;

    final tripDistance =
        await _tripsDao.sumDistanceForVehicle(vehicle.plateNumber);
    await _vehiclesDao.updateVehicle(
      VehiclesCompanion(
        id: Value(vehicleId),
        initialOdometer: Value(reading - tripDistance),
      ),
    );
    await correctOdometerChain(vehicleId);
  }
}
