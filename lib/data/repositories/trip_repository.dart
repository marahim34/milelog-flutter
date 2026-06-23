import '../database/app_database.dart';
import '../managers/odometer_manager.dart';

/// Mediates between ViewModels and [TripsDao].
///
/// UI and Notifiers must never call TripsDao directly — all trip reads and
/// writes go through this repository (see CLAUDE.md MVVM rule).
class TripRepository {
  TripRepository(this._tripsDao, this._vehiclesDao, this._odometerManager);

  final TripsDao _tripsDao;
  final VehiclesDao _vehiclesDao;
  final OdometerManager _odometerManager;

  /// Inserts a trip, then recomputes its vehicle's lastOdometer from the
  /// full trip history (see CLAUDE.md odometer-chain rule) — never just
  /// bump it by this trip's distance, since edits/deletes elsewhere could
  /// have left it out of sync.
  Future<int> insertTrip(TripsCompanion entry) async {
    final id = await _tripsDao.insertTrip(entry);

    final plate =
        entry.vehicleNumber.present ? entry.vehicleNumber.value : '';
    if (plate.isNotEmpty) {
      final vehicle = await _vehiclesDao.getByPlate(plate);
      if (vehicle != null) {
        await _odometerManager.correctOdometerChain(vehicle.id);
      }
    }

    return id;
  }

  Future<List<Trip>> getCompletedTrips() => _tripsDao.getCompletedTrips();

  Stream<List<Trip>> watchCompletedTrips() => _tripsDao.watchCompletedTrips();

  Future<Trip?> getTripById(int id) => _tripsDao.getTripById(id);

  Future<void> updateTrip(TripsCompanion entry) => _tripsDao.updateTrip(entry);

  Future<void> deleteTrip(int id) => _tripsDao.deleteTrip(id);

  Future<List<LocationPoint>> getLocationPointsForTrip(int tripId) =>
      _tripsDao.getPointsForTrip(tripId);
}
