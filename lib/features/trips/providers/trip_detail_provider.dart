import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';

class TripDetailState {
  const TripDetailState({
    required this.trip,
    required this.locationPoints,
    required this.waypoints,
  });

  final Trip trip;
  final List<LocationPoint> locationPoints;

  /// Real Bluetooth-disconnect/reconnect stops recorded during the trip,
  /// ordered oldest-first — see `TripRepository.recordPauseWaypoint`. Empty
  /// for trips with no Bluetooth-tracked vehicle or that predate this
  /// feature; the UI falls back to GPS-dwell-detected stops in that case.
  final List<TripWaypoint> waypoints;

  TripDetailState copyWith({
    Trip? trip,
    List<LocationPoint>? locationPoints,
    List<TripWaypoint>? waypoints,
  }) {
    return TripDetailState(
      trip: trip ?? this.trip,
      locationPoints: locationPoints ?? this.locationPoints,
      waypoints: waypoints ?? this.waypoints,
    );
  }
}

/// ViewModel for [TripDetailScreen]. Loads the trip and its recorded
/// location points/waypoints through [TripRepository] and persists edits
/// the same way — the UI never talks to TripRepository or the DAOs
/// directly (see CLAUDE.md MVVM rule).
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
    final waypoints = await repository.getWaypointsForTrip(tripId);
    return TripDetailState(
      trip: trip,
      locationPoints: locationPoints,
      waypoints: waypoints,
    );
  }

  Future<void> updateTripDetails({
    required TripType tripType,
    required String companyName,
    required String notes,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updatedTrip = current.trip.copyWith(
      tripType: tripType.value,
      companyName: companyName,
      notes: notes,
    );

    final repository = ref.read(tripRepositoryProvider);
    await repository.updateTrip(updatedTrip.toCompanion(true));
    state = AsyncData(current.copyWith(trip: updatedTrip));
  }

  Future<void> deleteTrip() async {
    final repository = ref.read(tripRepositoryProvider);
    await repository.deleteTrip(arg);
  }
}

final tripDetailProvider = AsyncNotifierProvider.autoDispose
    .family<TripDetailNotifier, TripDetailState, int>(TripDetailNotifier.new);
