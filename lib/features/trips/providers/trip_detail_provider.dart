import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';

class TripDetailState {
  const TripDetailState({required this.trip, required this.locationPoints});

  final Trip trip;
  final List<LocationPoint> locationPoints;

  TripDetailState copyWith({Trip? trip, List<LocationPoint>? locationPoints}) {
    return TripDetailState(
      trip: trip ?? this.trip,
      locationPoints: locationPoints ?? this.locationPoints,
    );
  }
}

/// ViewModel for [TripDetailScreen]. Loads the trip and its recorded
/// location points through [TripRepository] and persists edits the same
/// way — the UI never talks to TripRepository or TripsDao directly (see
/// CLAUDE.md MVVM rule).
class TripDetailNotifier
    extends AutoDisposeFamilyAsyncNotifier<TripDetailState, int> {
  @override
  Future<TripDetailState> build(int tripId) async {
    final repository = ref.watch(tripRepositoryProvider);
    final trip = await repository.getTripById(tripId);
    if (trip == null) {
      throw StateError('Trip $tripId not found');
    }
    final locationPoints = await repository.getLocationPointsForTrip(tripId);
    return TripDetailState(trip: trip, locationPoints: locationPoints);
  }

  Future<void> updateTripDetails({
    required TripType tripType,
    required String companyName,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedTrip = current.trip.copyWith(
      tripType: tripType.value,
      companyName: companyName,
    );

    final repository = ref.read(tripRepositoryProvider);
    await repository.updateTrip(updatedTrip.toCompanion(true));
    state = AsyncData(current.copyWith(trip: updatedTrip));
  }
}

final tripDetailProvider = AsyncNotifierProvider.autoDispose
    .family<TripDetailNotifier, TripDetailState, int>(TripDetailNotifier.new);
