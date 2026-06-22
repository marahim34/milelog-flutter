import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';

/// ViewModel for the completed-trips list shared by the Drive, Logs, and
/// Reports tabs. UI watches this Notifier; it never talks to TripRepository
/// or TripsDao directly (see CLAUDE.md MVVM rule).
class CompletedTripsNotifier extends StreamNotifier<List<Trip>> {
  @override
  Stream<List<Trip>> build() {
    final repository = ref.watch(tripRepositoryProvider);
    return repository.watchCompletedTrips();
  }
}

final completedTripsProvider =
    StreamNotifierProvider<CompletedTripsNotifier, List<Trip>>(
  CompletedTripsNotifier.new,
);
