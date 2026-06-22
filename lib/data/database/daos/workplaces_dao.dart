import 'package:drift/drift.dart';

import '../app_database.dart';

part 'workplaces_dao.g.dart';

@DriftAccessor(tables: [WorkPlaces])
class WorkPlacesDao extends DatabaseAccessor<AppDatabase> with _$WorkPlacesDaoMixin {
  WorkPlacesDao(super.db);

  Stream<List<WorkPlace>> watchAll() => select(workPlaces).watch();

  Future<List<WorkPlace>> getAll() => select(workPlaces).get();

  Future<WorkPlace?> getHome() =>
      (select(workPlaces)..where((w) => w.isHome.equals(true))).getSingleOrNull();

  Future<List<WorkPlace>> getGeofenceEnabled() =>
      (select(workPlaces)..where((w) => w.geofenceEnabled.equals(true))).get();

  Future<int> insert(WorkPlacesCompanion entry) =>
      into(workPlaces).insert(entry);

  Future<void> updateWorkPlace(WorkPlacesCompanion entry) =>
      (update(workPlaces)..where((w) => w.id.equals(entry.id.value))).write(entry);

  Future<void> deleteById(int id) =>
      (delete(workPlaces)..where((w) => w.id.equals(id))).go();
}
