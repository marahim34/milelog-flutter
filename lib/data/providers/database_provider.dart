import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';

/// Single database instance for the app lifetime.
/// Disposed (connection closed) when the ProviderScope is destroyed.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ── DAO providers ───────────────────────────────────────────────────────────
// One provider per DAO so features only depend on the DAO they need.

final tripsDaoProvider = Provider<TripsDao>(
  (ref) => ref.watch(databaseProvider).tripsDao,
);

final vehiclesDaoProvider = Provider<VehiclesDao>(
  (ref) => ref.watch(databaseProvider).vehiclesDao,
);

final odometerDaoProvider = Provider<OdometerDao>(
  (ref) => ref.watch(databaseProvider).odometerDao,
);

final workPlacesDaoProvider = Provider<WorkPlacesDao>(
  (ref) => ref.watch(databaseProvider).workPlacesDao,
);

final waypointsDaoProvider = Provider<WaypointsDao>(
  (ref) => ref.watch(databaseProvider).waypointsDao,
);
