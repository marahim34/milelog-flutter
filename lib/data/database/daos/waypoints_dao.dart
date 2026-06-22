import 'package:drift/drift.dart';

import '../app_database.dart';

part 'waypoints_dao.g.dart';

@DriftAccessor(tables: [TripWaypoints, TripEdits])
class WaypointsDao extends DatabaseAccessor<AppDatabase> with _$WaypointsDaoMixin {
  WaypointsDao(super.db);

  // ── Waypoints ────────────────────────────────────────────────────────────

  Future<int> insertWaypoint(TripWaypointsCompanion entry) =>
      into(tripWaypoints).insert(entry);

  Future<List<TripWaypoint>> getPausePointsForTrip(int tripId) =>
      (select(tripWaypoints)
            ..where((w) => w.tripId.equals(tripId) & w.isPause.equals(true))
            ..orderBy([(w) => OrderingTerm.asc(w.timestamp)]))
          .get();

  Future<List<TripWaypoint>> getAllWaypointsForTrip(int tripId) =>
      (select(tripWaypoints)
            ..where((w) => w.tripId.equals(tripId))
            ..orderBy([(w) => OrderingTerm.asc(w.timestamp)]))
          .get();

  Future<void> deleteWaypointsForTrip(int tripId) =>
      (delete(tripWaypoints)..where((w) => w.tripId.equals(tripId))).go();

  // ── Trip edits (audit trail) ─────────────────────────────────────────────

  Future<void> insertEdit(TripEditsCompanion entry) =>
      into(tripEdits).insert(entry);

  Stream<List<TripEdit>> watchEditsForTrip(int tripId) =>
      (select(tripEdits)
            ..where((e) => e.tripId.equals(tripId))
            ..orderBy([(e) => OrderingTerm.desc(e.timestamp)]))
          .watch();
}
