import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/constants/app_constants.dart';
import 'daos/trips_dao.dart';
import 'daos/vehicles_dao.dart';
import 'daos/odometer_dao.dart';
import 'daos/workplaces_dao.dart';
import 'daos/waypoints_dao.dart';
import 'tables/trips_table.dart';
import 'tables/location_points_table.dart';
import 'tables/trip_waypoints_table.dart';
import 'tables/vehicles_table.dart';
import 'tables/odometer_readings_table.dart';
import 'tables/workplaces_table.dart';
import 'tables/trip_edits_table.dart';

export 'tables/trips_table.dart';
export 'tables/location_points_table.dart';
export 'tables/trip_waypoints_table.dart';
export 'tables/vehicles_table.dart';
export 'tables/odometer_readings_table.dart';
export 'tables/workplaces_table.dart';
export 'tables/trip_edits_table.dart';
export 'daos/trips_dao.dart';
export 'daos/vehicles_dao.dart';
export 'daos/odometer_dao.dart';
export 'daos/workplaces_dao.dart';
export 'daos/waypoints_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Trips,
    LocationPoints,
    TripWaypoints,
    Vehicles,
    OdometerReadings,
    WorkPlaces,
    TripEdits,
  ],
  daos: [
    TripsDao,
    VehiclesDao,
    OdometerDao,
    WorkPlacesDao,
    WaypointsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => AppConstants.dbVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Add migration steps here as schemaVersion increments.
        },
        beforeOpen: (details) async {
          // Enable foreign key enforcement (SQLite disables it by default).
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

QueryExecutor _openConnection() {
  if (kIsWeb) {
    // Use in-memory database for web (data doesn't persist across page refreshes)
    // This is a simple solution for web compatibility - mobile/desktop use persistent storage
    return NativeDatabase.memory();
  } else {
    // Use native SQLite for mobile/desktop (persistent storage)
    return driftDatabase(name: AppConstants.dbName);
  }
}
