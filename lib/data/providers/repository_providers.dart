import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/trip_repository.dart';
import 'database_provider.dart';

/// Repository providers sit between DAO providers and feature Notifiers.
final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.watch(tripsDaoProvider)),
);
