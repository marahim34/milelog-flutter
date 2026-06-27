import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Mediates between ViewModels and [OdometerDao].
///
/// UI and Notifiers must never call OdometerDao directly — all reads and
/// writes go through this repository (see CLAUDE.md MVVM rule). Entries here
/// are a manual audit log, separate from the computed odometer chain (see
/// CLAUDE.md odometer-chain rule) — inserting a reading never touches
/// [Vehicle.lastOdometer].
class OdometerReadingRepository {
  OdometerReadingRepository(this._odometerDao);

  final OdometerDao _odometerDao;

  Future<List<OdometerReading>> getAllForVehicle(String plateNumber) =>
      _odometerDao.getAllForVehicle(plateNumber);

  Future<int> addReading({
    required String vehicleNumber,
    int? vehicleId,
    required double readingKm,
    required int timestamp,
    String notes = '',
  }) {
    return _odometerDao.insert(
      OdometerReadingsCompanion.insert(
        vehicleId: Value(vehicleId),
        vehicleNumber: vehicleNumber,
        readingKm: readingKm,
        timestamp: timestamp,
        notes: Value(notes),
      ),
    );
  }
}
