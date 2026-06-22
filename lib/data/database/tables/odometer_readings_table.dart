import 'package:drift/drift.dart';

/// Mirrors the `odometer_readings` Room entity — manual odometer log entries.
///
/// [vehicleNumber] is the primary link (plate number string), not a hard FK,
/// because readings can be entered before a vehicle is registered, allowing
/// backfill / correction of the odometer chain.
class OdometerReadings extends Table {
  @override
  String get tableName => 'odometer_readings';

  IntColumn get id => integer().autoIncrement()();

  /// Soft reference — nullable for legacy data that predates vehicle records.
  IntColumn get vehicleId => integer().nullable()();
  TextColumn get vehicleNumber => text()();
  RealColumn get readingKm => real()();
  IntColumn get timestamp => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get photoUri => text().nullable()();
}
