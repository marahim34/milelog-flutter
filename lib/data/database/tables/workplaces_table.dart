import 'package:drift/drift.dart';

/// Mirrors the `workplaces` Room entity — named locations used for geofencing.
class WorkPlaces extends Table {
  @override
  String get tableName => 'workplaces';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get address => text()();
  RealColumn get latitude => real().withDefault(const Constant(0.0))();
  RealColumn get longitude => real().withDefault(const Constant(0.0))();
  BoolColumn get isHome => boolean().withDefault(const Constant(false))();
  BoolColumn get geofenceEnabled => boolean().withDefault(const Constant(false))();

  /// Geofence trigger radius in metres (default 100m matches Room schema).
  RealColumn get radiusMeters => real().withDefault(const Constant(100.0))();
}
