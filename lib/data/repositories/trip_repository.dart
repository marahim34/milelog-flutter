import '../database/app_database.dart';

/// Mediates between ViewModels and [TripsDao].
///
/// UI and Notifiers must never call TripsDao directly — all trip reads and
/// writes go through this repository (see CLAUDE.md MVVM rule).
class TripRepository {
  TripRepository(this._tripsDao);

  final TripsDao _tripsDao;

  Future<int> insertTrip(TripsCompanion entry) => _tripsDao.insertTrip(entry);

  Future<List<Trip>> getCompletedTrips() => _tripsDao.getCompletedTrips();

  Stream<List<Trip>> watchCompletedTrips() => _tripsDao.watchCompletedTrips();

  Future<Trip?> getTripById(int id) => _tripsDao.getTripById(id);

  Future<void> updateTrip(TripsCompanion entry) => _tripsDao.updateTrip(entry);

  Future<void> deleteTrip(int id) => _tripsDao.deleteTrip(id);

  Future<List<LocationPoint>> getLocationPointsForTrip(int tripId) =>
      _tripsDao.getPointsForTrip(tripId);
}
