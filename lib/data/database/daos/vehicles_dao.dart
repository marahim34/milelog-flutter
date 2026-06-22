import 'package:drift/drift.dart';

import '../app_database.dart';

part 'vehicles_dao.g.dart';

@DriftAccessor(tables: [Vehicles])
class VehiclesDao extends DatabaseAccessor<AppDatabase> with _$VehiclesDaoMixin {
  VehiclesDao(super.db);

  Stream<List<Vehicle>> watchAll() =>
      (select(vehicles)..orderBy([(v) => OrderingTerm.asc(v.name)])).watch();

  Future<List<Vehicle>> getAll() => select(vehicles).get();

  Future<Vehicle?> getDefault() =>
      (select(vehicles)..where((v) => v.isDefault.equals(true))).getSingleOrNull();

  Future<Vehicle?> getByPlate(String plate) =>
      (select(vehicles)..where((v) => v.plateNumber.equals(plate))).getSingleOrNull();

  Future<Vehicle?> getById(int id) =>
      (select(vehicles)..where((v) => v.id.equals(id))).getSingleOrNull();

  Future<int> insertVehicle(VehiclesCompanion entry) =>
      into(vehicles).insert(entry);

  Future<void> updateVehicle(VehiclesCompanion entry) =>
      (update(vehicles)..where((v) => v.id.equals(entry.id.value))).write(entry);

  Future<void> deleteVehicle(int id) =>
      (delete(vehicles)..where((v) => v.id.equals(id))).go();

  /// Clears isDefault on all vehicles — call before setting a new default.
  Future<void> clearDefault() =>
      update(vehicles).write(const VehiclesCompanion(isDefault: Value(false)));

  /// Updates lastOdometer cache for a single vehicle (called by OdometerManager).
  Future<void> updateLastOdometer(int id, double value) =>
      (update(vehicles)..where((v) => v.id.equals(id)))
          .write(VehiclesCompanion(lastOdometer: Value(value)));
}
