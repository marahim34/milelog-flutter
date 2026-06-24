import 'package:drift/drift.dart';

/// Mirrors the `location_points` Room entity — one row per GPS sample during tracking.
class LocationPoints extends Table {
  @override
  String get tableName => 'location_points';

  IntColumn get id => integer().autoIncrement()();

  /// CASCADE delete when the parent trip is deleted.
  IntColumn get tripId => integer()
      .customConstraint('NOT NULL REFERENCES trips(id) ON DELETE CASCADE')();

  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get speedKmh => real().withDefault(const Constant(0.0))();
  RealColumn get accuracyMeters => real().withDefault(const Constant(0.0))();
  RealColumn get altitude => real().withDefault(const Constant(0.0))();
  IntColumn get timestamp => integer()();
  TextColumn get provider => text().withDefault(const Constant('gps'))();

  // Add @TableIndex(name: 'idx_lp_trip', columns: {#tripId}) at class level
  // once drift_dev is installed and the Drift Index API is confirmed.
}
