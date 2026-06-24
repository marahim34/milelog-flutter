import 'package:drift/drift.dart';

/// Mirrors the `vehicles` Room entity.
///
/// Important: [lastOdometer] is a computed value — always derive it from
/// initialOdometer + Σ(trip distances for this vehicle). Never set it directly
/// without going through OdometerManager logic. See CLAUDE.md.
class Vehicles extends Table {
  @override
  String get tableName => 'vehicles';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Plate number is the cross-table identifier (used in trips, odometer_readings).
  TextColumn get plateNumber => text()();

  /// 0.0 means "use the global app default rate".
  RealColumn get defaultMileageRate =>
      real().withDefault(const Constant(0.0))();

  /// Odometer reading when the vehicle was first added to the app.
  RealColumn get initialOdometer => real().withDefault(const Constant(0.0))();

  /// Cached computed value: initialOdometer + Σ(trip distances). Updated by OdometerManager.
  RealColumn get lastOdometer => real().withDefault(const Constant(0.0))();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get bluetoothMac => text().nullable()();
  BoolColumn get bluetoothAutoStart =>
      boolean().withDefault(const Constant(true))();
}
