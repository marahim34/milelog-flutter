import 'package:drift/drift.dart';
import 'package:latlong2/latlong.dart';

import '../database/app_database.dart';
import '../managers/odometer_manager.dart';
import '../models/trip_type.dart';
import '../services/reverse_geocoder.dart';

/// Mediates between ViewModels and [TripsDao]/[WaypointsDao].
///
/// UI and Notifiers must never call the DAOs directly — all trip, location
/// point, and waypoint reads and writes go through this repository (see
/// CLAUDE.md MVVM rule).
class TripRepository {
  TripRepository(
    this._tripsDao,
    this._vehiclesDao,
    this._odometerManager,
    this._waypointsDao,
  );

  final TripsDao _tripsDao;
  final VehiclesDao _vehiclesDao;
  final OdometerManager _odometerManager;
  final WaypointsDao _waypointsDao;

  /// Inserts a trip, then recomputes its vehicle's lastOdometer from the
  /// full trip history (see CLAUDE.md odometer-chain rule) — never just
  /// bump it by this trip's distance, since edits/deletes elsewhere could
  /// have left it out of sync.
  Future<int> insertTrip(TripsCompanion entry) async {
    final id = await _tripsDao.insertTrip(entry);

    final plate = entry.vehicleNumber.present ? entry.vehicleNumber.value : '';
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

  Future<Trip?> getActiveTripForVehicle(String vehicleNumber) async {
    final active = await _tripsDao.getActiveTrip();
    if (active == null || active.vehicleNumber != vehicleNumber) return null;
    return active;
  }

  /// Returns all active trips (for crash recovery detection on app launch).
  Future<List<Trip>> getActiveTrips() => _tripsDao.getActiveTrips();

  Future<void> updateTrip(TripsCompanion entry) => _tripsDao.updateTrip(entry);

  /// Deletes the trip, then recomputes its vehicle's lastOdometer — a
  /// deleted trip's distance must come back out of the chain, same as
  /// [insertTrip]/[finalizeTrip] put it in.
  Future<void> deleteTrip(int id) async {
    final trip = await _tripsDao.getTripById(id);
    await _tripsDao.deleteTrip(id);

    final plate = trip?.vehicleNumber ?? '';
    if (plate.isNotEmpty) {
      final vehicle = await _vehiclesDao.getByPlate(plate);
      if (vehicle != null) {
        await _odometerManager.correctOdometerChain(vehicle.id);
      }
    }
  }

  /// Records the trip's starting point — called once, from the first GPS
  /// fix of a live trip, so logs_tab.dart's trip cards have a start address
  /// to show without waiting for the trip to finish.
  Future<void> updateTripStartLocation({
    required int tripId,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    await _tripsDao.updateTrip(
      TripsCompanion(
        id: Value(tripId),
        startLat: Value(latitude),
        startLng: Value(longitude),
        startAddress: Value(address),
      ),
    );
  }

  /// Finalizes the trip row that [insertTrip] created when tracking
  /// started — see CLAUDE.md: distance is calculated on stop, not written
  /// incrementally, so this is the one point where the authoritative
  /// distance/speed/classification fields are written. Recomputes the
  /// vehicle's lastOdometer afterwards, same as [insertTrip].
  Future<void> finalizeTrip({
    required int tripId,
    required int endTime,
    required double distanceKm,
    required double maxSpeedKmh,
    required double avgSpeedKmh,
    required TripType tripType,
    required String companyName,
    required String vehicleNumber,
    required double odometerStart,
    required double odometerEnd,
    required double mileageRate,
    required String notes,
    double? endLat,
    double? endLng,
    String endAddress = '',
  }) async {
    await _tripsDao.updateTrip(
      TripsCompanion(
        id: Value(tripId),
        endTime: Value(endTime),
        distanceKm: Value(distanceKm),
        maxSpeedKmh: Value(maxSpeedKmh),
        avgSpeedKmh: Value(avgSpeedKmh),
        isActive: const Value(false),
        tripType: Value(tripType.value),
        companyName: Value(companyName),
        vehicleNumber: Value(vehicleNumber),
        odometerStart: Value(odometerStart),
        odometerEnd: Value(odometerEnd),
        mileageRate: Value(mileageRate),
        notes: Value(notes),
        endLat: Value(endLat),
        endLng: Value(endLng),
        endAddress: Value(endAddress),
      ),
    );

    if (vehicleNumber.isNotEmpty) {
      final vehicle = await _vehiclesDao.getByPlate(vehicleNumber);
      if (vehicle != null) {
        await _odometerManager.correctOdometerChain(vehicle.id);
      }
    }
  }

  Future<List<LocationPoint>> getLocationPointsForTrip(int tripId) =>
      _tripsDao.getPointsForTrip(tripId);

  Future<int> insertLocationPoint(LocationPointsCompanion entry) =>
      _tripsDao.insertLocationPoint(entry);

  /// Recomputes distance travelled so far from the points already
  /// persisted to `location_points` — unlike [LocationTrackingService]'s
  /// in-memory running total, this works even when there's no live
  /// service instance (e.g. a headless Bluetooth-triggered wake), since it
  /// reads purely from the database.
  Future<double> calculateDistanceFromPersistedPoints(int tripId) async {
    final points = await getLocationPointsForTrip(tripId);
    if (points.length < 2) return 0;
    var total = 0.0;
    const distance = Distance();
    for (var i = 1; i < points.length; i++) {
      total += distance.as(
            LengthUnit.Kilometer,
            LatLng(points[i - 1].latitude, points[i - 1].longitude),
            LatLng(points[i].latitude, points[i].longitude),
          );
    }
    return total;
  }

  // ── Waypoints ──────────────────────────────────────────────────────────

  Future<List<TripWaypoint>> getWaypointsForTrip(int tripId) =>
      _waypointsDao.getAllWaypointsForTrip(tripId);

  /// Records a Bluetooth-disconnect-triggered stop. Never call this for a
  /// disconnect inside the 3-minute merge window — only once the merge
  /// timer confirms the stop is real (see `BluetoothAutoTrackingController`).
  Future<void> recordPauseWaypoint({
    required int tripId,
    required double latitude,
    required double longitude,
    required double distanceKmAtStop,
  }) async {
    final address = await ReverseGeocoder.lookup(latitude, longitude);
    await _waypointsDao.insertWaypoint(
      TripWaypointsCompanion.insert(
        tripId: tripId,
        latitude: latitude,
        longitude: longitude,
        address: Value(address),
        distanceKmAtStop: Value(distanceKmAtStop),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isPause: const Value(true),
      ),
    );
  }

  /// Records resuming after a committed stop (i.e. the merge timer had
  /// already fired and [recordPauseWaypoint] already ran for this stop).
  Future<void> recordResumeWaypoint({
    required int tripId,
    required double latitude,
    required double longitude,
    required double distanceKmAtStop,
  }) async {
    final address = await ReverseGeocoder.lookup(latitude, longitude);
    await _waypointsDao.insertWaypoint(
      TripWaypointsCompanion.insert(
        tripId: tripId,
        latitude: latitude,
        longitude: longitude,
        address: Value(address),
        distanceKmAtStop: Value(distanceKmAtStop),
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isPause: const Value(false),
      ),
    );
  }
}
