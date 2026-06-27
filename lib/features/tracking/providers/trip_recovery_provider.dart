import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';
import 'tracking_notifier.dart';

/// Detects and handles crashed/interrupted trips on app launch.
///
/// On startup, checks for:
/// 1. Persisted trip state in SharedPreferences (written every 30s during tracking)
/// 2. Active trips in the database (Trip.isActive = true)
///
/// If found, offers the user options to continue or finalize the trip.
class TripRecoveryNotifier extends StateNotifier<TripRecoveryState> {
  TripRecoveryNotifier(this._ref) : super(const TripRecoveryState.initial()) {
    _checkForActiveTrips();
  }

  final Ref _ref;

  Future<void> _checkForActiveTrips() async {
    // Check SharedPreferences for persisted state (most recent data)
    final persistedState = await TrackingNotifier.loadPersistedState();

    // Check database for isActive = true trips (fallback if prefs cleared)
    final repository = _ref.read(tripRepositoryProvider);
    final activeTrips = await repository.getActiveTrips();

    if (persistedState != null || activeTrips.isNotEmpty) {
      final tripId = persistedState?.tripId ?? activeTrips.first.id;
      final startTime = persistedState?.startTimeMs ?? activeTrips.first.startTime;
      final distance = persistedState?.distance ?? activeTrips.first.distanceKm;

      state = TripRecoveryState.needsRecovery(
        tripId: tripId,
        startTimeMs: startTime,
        distanceKm: distance,
      );
    } else {
      state = const TripRecoveryState.noRecoveryNeeded();
    }
  }

  /// Finalizes the interrupted trip with the data already saved to the DB —
  /// distance from persisted location points, end time set to now. The user
  /// will still be able to edit the trip from the logs screen.
  Future<void> finalizeAndStopTrip() async {
    if (state is! TripRecoveryNeedsRecovery) return;
    final s = state as TripRecoveryNeedsRecovery;

    final repository = _ref.read(tripRepositoryProvider);
    final trip = await repository.getTripById(s.tripId);

    if (trip != null && trip.isActive) {
      final persistedDistance =
          await repository.calculateDistanceFromPersistedPoints(s.tripId);
      final distanceKm =
          persistedDistance > 0 ? persistedDistance : trip.distanceKm;

      await repository.finalizeTrip(
        tripId: s.tripId,
        endTime: DateTime.now().millisecondsSinceEpoch,
        distanceKm: distanceKm,
        maxSpeedKmh: trip.maxSpeedKmh,
        avgSpeedKmh: trip.avgSpeedKmh,
        tripType: TripType.fromString(trip.tripType),
        companyName: trip.companyName,
        vehicleNumber: trip.vehicleNumber,
        odometerStart: trip.odometerStart,
        odometerEnd: trip.odometerStart + distanceKm,
        mileageRate: trip.mileageRate,
        notes: trip.notes,
        endLat: trip.endLat,
        endLng: trip.endLng,
        endAddress: trip.endAddress,
      );
    }

    await TrackingNotifier.clearPersistedState();
    state = const TripRecoveryState.noRecoveryNeeded();
  }

  /// User chose to continue the interrupted trip (navigate to tracking screen).
  void markAsResumed() {
    state = const TripRecoveryState.noRecoveryNeeded();
  }
}

sealed class TripRecoveryState {
  const TripRecoveryState();

  const factory TripRecoveryState.initial() = TripRecoveryInitial;
  const factory TripRecoveryState.needsRecovery({
    required int tripId,
    required int startTimeMs,
    required double distanceKm,
  }) = TripRecoveryNeedsRecovery;
  const factory TripRecoveryState.noRecoveryNeeded() = TripRecoveryNoRecoveryNeeded;
}

class TripRecoveryInitial extends TripRecoveryState {
  const TripRecoveryInitial();
}

class TripRecoveryNeedsRecovery extends TripRecoveryState {
  const TripRecoveryNeedsRecovery({
    required this.tripId,
    required this.startTimeMs,
    required this.distanceKm,
  });

  final int tripId;
  final int startTimeMs;
  final double distanceKm;
}

class TripRecoveryNoRecoveryNeeded extends TripRecoveryState {
  const TripRecoveryNoRecoveryNeeded();
}

final tripRecoveryProvider =
    StateNotifierProvider<TripRecoveryNotifier, TripRecoveryState>(
  TripRecoveryNotifier.new,
);
