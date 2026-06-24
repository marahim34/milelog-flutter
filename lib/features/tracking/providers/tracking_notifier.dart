import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/background_tracking_service.dart';
import '../../../data/services/location_tracking_service.dart';
import '../../../data/services/mileage_rate_service.dart';

enum TrackingStatus {
  requestingPermission,
  permissionDenied,
  serviceDisabled,
  active,
  paused,
  stopped,
}

class TrackingViewState {
  const TrackingViewState({
    required this.status,
    required this.currentPosition,
    required this.routePoints,
    required this.currentSpeedKmh,
    required this.maxSpeedKmh,
    required this.totalDistanceKm,
    required this.elapsedSeconds,
    required this.startTimeMs,
  });

  final TrackingStatus status;
  final LatLng? currentPosition;
  final List<LatLng> routePoints;
  final double currentSpeedKmh;
  final double maxSpeedKmh;
  final double totalDistanceKm;
  final int elapsedSeconds;
  final int startTimeMs;

  factory TrackingViewState.initial() => TrackingViewState(
        status: TrackingStatus.requestingPermission,
        currentPosition: null,
        routePoints: const [],
        currentSpeedKmh: 0,
        maxSpeedKmh: 0,
        totalDistanceKm: 0,
        elapsedSeconds: 0,
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
      );

  TrackingViewState copyWith({
    TrackingStatus? status,
    LatLng? currentPosition,
    List<LatLng>? routePoints,
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    double? totalDistanceKm,
    int? elapsedSeconds,
    int? startTimeMs,
  }) {
    return TrackingViewState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      routePoints: routePoints ?? this.routePoints,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      startTimeMs: startTimeMs ?? this.startTimeMs,
    );
  }
}

/// ViewModel for [TrackingScreen]. Owns a [LocationTrackingService] for the
/// lifetime of the active trip and persists the finished trip through
/// [TripRepository] — the UI never talks to the service internals or the
/// repository directly (see CLAUDE.md MVVM rule).
class TrackingNotifier extends AutoDisposeNotifier<TrackingViewState> {
  late final LocationTrackingService _locationService;
  Timer? _elapsedTimer;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<TrackedPoint>? _trackedPointSub;
  StreamSubscription<double>? _speedSub;
  StreamSubscription<double>? _distanceSub;
  bool _disposed = false;

  @override
  TrackingViewState build() {
    _locationService = LocationTrackingService();
    ref.onDispose(() {
      _disposed = true;
      _elapsedTimer?.cancel();
      _positionSub?.cancel();
      _trackedPointSub?.cancel();
      _speedSub?.cancel();
      _distanceSub?.cancel();
      _locationService.dispose();
      unawaited(BackgroundTrackingService.stop());
    });
    unawaited(_initialize());
    return TrackingViewState.initial();
  }

  Future<void> _initialize() async {
    final access = await _locationService.ensureLocationAccess();
    if (_disposed) return;

    if (access != LocationAccessStatus.granted) {
      state = state.copyWith(status: _statusFor(access));
      return;
    }

    state = state.copyWith(
      status: TrackingStatus.active,
      startTimeMs: DateTime.now().millisecondsSinceEpoch,
    );

    await BackgroundTrackingService.start();
    if (_disposed) return;

    await _locationService.start();
    if (_disposed) return;

    _positionSub = _locationService.positionStream.listen(_onRawPosition);
    _trackedPointSub =
        _locationService.trackedPointStream.listen(_onTrackedPoint);
    _speedSub = _locationService.speedStream.listen((speedKmh) {
      state = state.copyWith(
        currentSpeedKmh: speedKmh,
        maxSpeedKmh:
            speedKmh > state.maxSpeedKmh ? speedKmh : state.maxSpeedKmh,
      );
    });
    _distanceSub = _locationService.distanceStream.listen((distanceKm) {
      state = state.copyWith(totalDistanceKm: distanceKm);
    });

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == TrackingStatus.active) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
      unawaited(BackgroundTrackingService.updateNotification(
        distanceKm: state.totalDistanceKm,
        elapsedSeconds: state.elapsedSeconds,
      ));
    });
  }

  /// Re-attempts the permission/service check — call from a "retry" button
  /// when [TrackingViewState.status] is [TrackingStatus.permissionDenied] or
  /// [TrackingStatus.serviceDisabled].
  Future<void> retry() => _initialize();

  /// Updates the live marker position. Raw fixes can be noisy, so this must
  /// not feed the route polyline — see [_onTrackedPoint].
  void _onRawPosition(Position position) {
    state = state.copyWith(
      currentPosition: LatLng(position.latitude, position.longitude),
    );
  }

  /// Appends a point that passed [LocationTrackingService]'s accuracy
  /// filter to the route — the same points the live/final distance is
  /// computed from, so the drawn route and the distance never disagree.
  void _onTrackedPoint(TrackedPoint point) {
    state = state.copyWith(
      routePoints: [
        ...state.routePoints,
        LatLng(point.latitude, point.longitude),
      ],
    );
  }

  TrackingStatus _statusFor(LocationAccessStatus access) {
    switch (access) {
      case LocationAccessStatus.serviceDisabled:
        return TrackingStatus.serviceDisabled;
      case LocationAccessStatus.permissionDenied:
      case LocationAccessStatus.permissionDeniedForever:
        return TrackingStatus.permissionDenied;
      case LocationAccessStatus.granted:
        return TrackingStatus.active;
    }
  }

  void pause() {
    if (state.status != TrackingStatus.active) return;
    unawaited(_locationService.pause());
    state = state.copyWith(status: TrackingStatus.paused);
  }

  void resume() {
    if (state.status != TrackingStatus.paused) return;
    unawaited(_locationService.resume());
    state = state.copyWith(status: TrackingStatus.active);
  }

  /// Stops GPS updates and persists the trip via [TripRepository], using
  /// the distance recomputed from the full point list (not the live running
  /// total) as the authoritative value.
  Future<void> stopAndSave({
    required TripType tripType,
    required String companyName,
    required String vehicleNumber,
  }) async {
    _elapsedTimer?.cancel();
    await _locationService.stop();
    await BackgroundTrackingService.stop();
    if (_disposed) return;

    final distanceKm = _locationService.calculateTotalDistance();
    final endTimeMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = state.elapsedSeconds;
    final avgSpeedKmh =
        elapsedSeconds > 0 ? (distanceKm / elapsedSeconds) * 3600 : 0.0;

    state = state.copyWith(
      status: TrackingStatus.stopped,
      totalDistanceKm: distanceKm,
    );

    final repository = ref.read(tripRepositoryProvider);
    final vehicleRepository = ref.read(vehicleRepositoryProvider);
    final vehicle = await vehicleRepository.getByPlate(vehicleNumber);
    final globalRate = await MileageRateService.getRate();
    final effectiveRate = (vehicle != null && vehicle.defaultMileageRate > 0)
        ? vehicle.defaultMileageRate
        : globalRate;

    await repository.insertTrip(
      TripsCompanion.insert(
        startTime: state.startTimeMs,
        endTime: Value(endTimeMs),
        distanceKm: Value(distanceKm),
        maxSpeedKmh: Value(_locationService.maxSpeedKmh),
        avgSpeedKmh: Value(avgSpeedKmh),
        isActive: const Value(false),
        tripType: Value(tripType.value),
        startAddress: const Value(''),
        endAddress: const Value(''),
        companyName: Value(companyName),
        vehicleNumber: Value(vehicleNumber),
        odometerStart: const Value(0.0),
        odometerEnd: const Value(0.0),
        mileageRate: Value(effectiveRate),
        notes: const Value(''),
        isSynced: const Value(false),
        autoStarted: const Value(false),
      ),
    );
  }
}

final trackingNotifierProvider =
    NotifierProvider.autoDispose<TrackingNotifier, TrackingViewState>(
  TrackingNotifier.new,
);
