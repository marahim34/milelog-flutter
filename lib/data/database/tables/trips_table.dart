import 'package:drift/drift.dart';

/// Mirrors the `trips` Room entity (the primary mileage record).
class Trips extends Table {
  @override
  String get tableName => 'trips';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get startTime => integer()();
  IntColumn get endTime => integer().nullable()();
  RealColumn get distanceKm => real().withDefault(const Constant(0.0))();
  RealColumn get maxSpeedKmh => real().withDefault(const Constant(0.0))();
  RealColumn get avgSpeedKmh => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get startAddress => text().withDefault(const Constant(''))();
  TextColumn get endAddress => text().withDefault(const Constant(''))();
  RealColumn get startLat => real().nullable()();
  RealColumn get startLng => real().nullable()();
  RealColumn get endLat => real().nullable()();
  RealColumn get endLng => real().nullable()();

  /// 'PERSONAL' or 'BUSINESS' — stored as string to match Room schema.
  TextColumn get tripType => text().withDefault(const Constant('PERSONAL'))();
  TextColumn get companyName => text().withDefault(const Constant(''))();
  TextColumn get vehicleNumber => text().withDefault(const Constant(''))();
  RealColumn get odometerStart => real().withDefault(const Constant(0.0))();
  RealColumn get odometerEnd => real().withDefault(const Constant(0.0))();
  RealColumn get mileageRate => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get autoStarted => boolean().withDefault(const Constant(false))();
}
