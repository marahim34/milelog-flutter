import 'package:drift/drift.dart';

/// Mirrors the `trip_waypoints` Room entity — pause stops and intermediate waypoints.
class TripWaypoints extends Table {
  @override
  String get tableName => 'trip_waypoints';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get tripId => integer()
      .customConstraint('NOT NULL REFERENCES trips(id) ON DELETE CASCADE')();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get address => text().withDefault(const Constant(''))();

  /// Cumulative distance at the moment this stop was recorded (km).
  RealColumn get distanceKmAtStop => real().withDefault(const Constant(0.0))();
  IntColumn get timestamp => integer()();

  /// true = pause marker, false = named intermediate stop.
  BoolColumn get isPause => boolean().withDefault(const Constant(true))();

  // Add @TableIndex(name: 'idx_tw_trip', columns: {#tripId}) at class level
  // once drift_dev is installed and the Drift Index API is confirmed.
}
