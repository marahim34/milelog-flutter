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
}
