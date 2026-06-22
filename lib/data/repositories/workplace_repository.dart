import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Mediates between ViewModels and [WorkPlacesDao].
///
/// UI and Notifiers must never call WorkPlacesDao directly — all workplace
/// reads and writes go through this repository (see CLAUDE.md MVVM rule).
class WorkplaceRepository {
  WorkplaceRepository(this._workPlacesDao);

  final WorkPlacesDao _workPlacesDao;

  Stream<List<WorkPlace>> watchAll() => _workPlacesDao.watchAll();

  Future<WorkPlace?> getById(int id) => _workPlacesDao.getById(id);

  /// Inserts a new workplace, clearing any existing home workplace first so
  /// exactly one workplace is ever marked home.
  Future<int> addWorkplace({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool isHome,
  }) async {
    if (isHome) {
      await _workPlacesDao.clearHome();
    }
    return _workPlacesDao.insert(
      WorkPlacesCompanion.insert(
        name: name,
        address: address,
        latitude: Value(latitude),
        longitude: Value(longitude),
        radiusMeters: Value(radiusMeters),
        isHome: Value(isHome),
      ),
    );
  }

  Future<void> updateWorkplaceDetails({
    required WorkPlace existing,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool isHome,
  }) async {
    if (isHome) {
      await _workPlacesDao.clearHome();
    }
    await _workPlacesDao.updateWorkPlace(
      existing
          .copyWith(
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            radiusMeters: radiusMeters,
            isHome: isHome,
          )
          .toCompanion(true),
    );
  }

  Future<void> deleteWorkplace(int id) => _workPlacesDao.deleteById(id);
}
