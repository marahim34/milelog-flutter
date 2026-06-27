import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/odometer_repository.dart';
import '../repositories/trip_repository.dart';
import '../repositories/vehicle_repository.dart';
import '../repositories/workplace_repository.dart';
import 'database_provider.dart';

/// Repository providers sit between DAO providers and feature Notifiers.
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(
    ref.watch(tripsDaoProvider),
    ref.watch(vehiclesDaoProvider),
    ref.watch(odometerManagerProvider),
    ref.watch(waypointsDaoProvider),
  ),
);

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(
    ref.watch(vehiclesDaoProvider),
    ref.watch(odometerManagerProvider),
  ),
);

final workplaceRepositoryProvider = Provider<WorkplaceRepository>(
  (ref) => WorkplaceRepository(ref.watch(workPlacesDaoProvider)),
);

final odometerReadingRepositoryProvider = Provider<OdometerReadingRepository>(
  (ref) => OdometerReadingRepository(ref.watch(odometerDaoProvider)),
);
