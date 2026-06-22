import 'package:drift/drift.dart';

import '../app_database.dart';

part 'trips_dao.g.dart';

@DriftAccessor(tables: [Trips, LocationPoints])
class TripsDao extends DatabaseAccessor<AppDatabase> with _$TripsDaoMixin {
  TripsDao(super.db);

  // ── Active trip ─────────────────────────────────────────────────────────

  Future<Trip?> getActiveTrip() =>
      (select(trips)..where((t) => t.isActive.equals(true))).getSingleOrNull();

  Stream<Trip?> watchActiveTrip() =>
      (select(trips)..where((t) => t.isActive.equals(true))).watchSingleOrNull();

  // ── Trip queries ─────────────────────────────────────────────────────────

  Future<Trip?> getTripById(int id) =>
      (select(trips)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Trip>> watchCompletedTrips() => (select(trips)
        ..where((t) => t.isActive.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
      .watch();

  Future<List<Trip>> getCompletedTrips() => (select(trips)
        ..where((t) => t.isActive.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
      .get();

  Future<List<Trip>> getCompletedTripsPaged(int offset, int limit) =>
      (select(trips)
            ..where((t) => t.isActive.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
            ..limit(limit, offset: offset))
          .get();

  Future<int> countCompletedTrips() async {
    final count = trips.id.count();
    final q = selectOnly(trips)
      ..addColumns([count])
      ..where(trips.isActive.equals(false));
    return (await q.getSingle()).read(count) ?? 0;
  }

  Future<List<Trip>> getTripsInRange(int startMs, int endMs) =>
      (select(trips)
            ..where(
              (t) =>
                  t.startTime.isBiggerOrEqualValue(startMs) &
                  t.startTime.isSmallerOrEqualValue(endMs),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
          .get();

  Future<List<Trip>> getUnsyncedTrips() => (select(trips)
        ..where(
          (t) => t.isSynced.equals(false) & t.isActive.equals(false),
        ))
      .get();

  Future<List<Trip>> getAllTrips() => select(trips).get();

  // ── Trip mutations ───────────────────────────────────────────────────────

  Future<int> insertTrip(TripsCompanion entry) => into(trips).insert(entry);

  Future<void> updateTrip(TripsCompanion entry) =>
      (update(trips)..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<void> deleteTrip(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  Future<void> markSynced(int id) =>
      (update(trips)..where((t) => t.id.equals(id)))
          .write(const TripsCompanion(isSynced: Value(true)));

  // ── Location points ──────────────────────────────────────────────────────

  Future<int> insertLocationPoint(LocationPointsCompanion entry) =>
      into(locationPoints).insert(entry);

  Future<List<LocationPoint>> getPointsForTrip(int tripId) =>
      (select(locationPoints)
            ..where((p) => p.tripId.equals(tripId))
            ..orderBy([(p) => OrderingTerm.asc(p.timestamp)]))
          .get();

  Future<LocationPoint?> getLastPointForTrip(int tripId) =>
      (select(locationPoints)
            ..where((p) => p.tripId.equals(tripId))
            ..orderBy([(p) => OrderingTerm.desc(p.timestamp)])
            ..limit(1))
          .getSingleOrNull();

  Future<void> deletePointsForTrip(int tripId) =>
      (delete(locationPoints)..where((p) => p.tripId.equals(tripId))).go();

  Future<int> countPointsForTrip(int tripId) async {
    final count = locationPoints.id.count();
    final q = selectOnly(locationPoints)
      ..addColumns([count])
      ..where(locationPoints.tripId.equals(tripId));
    return (await q.getSingle()).read(count) ?? 0;
  }
}
