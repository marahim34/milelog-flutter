import 'package:drift/drift.dart';

/// Mirrors the `trip_edits` Room entity — immutable audit trail of field changes.
class TripEdits extends Table {
  @override
  String get tableName => 'trip_edits';

  IntColumn get id => integer().autoIncrement()();

  IntColumn get tripId => integer()
      .customConstraint('NOT NULL REFERENCES trips(id) ON DELETE CASCADE')();

  TextColumn get fieldChanged => text()();
  TextColumn get oldValue => text()();
  TextColumn get newValue => text()();
  IntColumn get timestamp => integer()();

  // Add @TableIndex(name: 'idx_te_trip', columns: {#tripId}) at class level
  // once drift_dev is installed and the Drift Index API is confirmed.
}
