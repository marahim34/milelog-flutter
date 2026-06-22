import 'package:drift/drift.dart';

import '../app_database.dart';

part 'odometer_dao.g.dart';

@DriftAccessor(tables: [OdometerReadings])
class OdometerDao extends DatabaseAccessor<AppDatabase> with _$OdometerDaoMixin {
  OdometerDao(super.db);

  Stream<List<OdometerReading>> watchAll() =>
      (select(odometerReadings)
            ..orderBy([(r) => OrderingTerm.desc(r.timestamp)]))
          .watch();

  Future<List<OdometerReading>> getAll() => select(odometerReadings).get();

  Future<OdometerReading?> getLatestForVehicle(String plateNumber) =>
      (select(odometerReadings)
            ..where((r) => r.vehicleNumber.equals(plateNumber))
            ..orderBy([(r) => OrderingTerm.desc(r.timestamp)])
            ..limit(1))
          .getSingleOrNull();

  Future<List<OdometerReading>> getAllForVehicle(String plateNumber) =>
      (select(odometerReadings)
            ..where((r) => r.vehicleNumber.equals(plateNumber))
            ..orderBy([(r) => OrderingTerm.asc(r.timestamp)]))
          .get();

  Future<int> insert(OdometerReadingsCompanion entry) =>
      into(odometerReadings).insert(entry);

  Future<void> deleteById(int id) =>
      (delete(odometerReadings)..where((r) => r.id.equals(id))).go();
}
