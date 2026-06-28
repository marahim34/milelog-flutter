import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/trip_repository.dart';
import '../../../data/services/background_tracking_service.dart';
import '../../../data/services/location_tracking_service.dart';
import '../../../data/services/mileage_rate_service.dart';
import '../../../data/services/reverse_geocoder.dart';
import 'tracking_screen_args.dart';

/// One-shot init data consumed by [TrackingNotifier.build]/`_initialize`.
///
/// A plain static holder, not a Riverpod provider — Riverpod forbids
/// modifying a provider synchronously from a widget lifecycle method
/// (`initState`/`build`/etc.), but that's exactly when the value must be
/// set: whoever is about to cause [trackingNotifierProvider] to be read for
/// the first time (`TrackingScreen.initState`) sets this synchronously
/// first, and `_initialize` reads-and-clears it once, before any `await`.
/// Turning [trackingNotifierProvider] into a `.family<..., TrackingScreenArgs?>`
/// instead was considered, but `TrackingScreenArgs` has no `==`/`hashCode`
/// override, so two call sites constructing "equivalent" args would resolve
/// to two different provider instances under family identity, breaking
/// `BluetoothAutoTrackingController`'s `ref.exists(...)`/pause/resume
/// control of the one live notifier.
class PendingTrackingArgs {
  PendingTrackingArgs._();
  static TrackingScreenArgs? value;
}

/// A point-in-time read of the live trip, used by Bluetooth-driven waypoint
/// recording to snapshot "where are we and how far have we gone" without
/// duplicating [LocationTrackingService]'s state.
class TrackingSnapshot {
  const TrackingSnapshot({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });

  final int tripId;
  final double latitude;
  final double longitude;
  final double distanceKm;
}

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
    required this.pauseWaypoints,
    required this.currentSpeedKmh,
    required this.maxSpeedKmh,
    required this.totalDistanceKm,
    required this.elapsedSeconds,
    required this.startTimeMs,
    required this.tripId,
    required this.isInactivityWarning,
    this.isAutoStopped = false,
  });

  final TrackingStatus status;
  final LatLng? currentPosition;
  final List<LatLng> routePoints;

  /// Positions where the user manually paused — rendered as stop markers on
  /// the live map so the driver can see recorded stops mid-trip.
  final List<LatLng> pauseWaypoints;

  final double currentSpeedKmh;
  final double maxSpeedKmh;
  final double totalDistanceKm;
  final int elapsedSeconds;
  final int startTimeMs;

  /// The trip row's id, created up front when tracking starts (not at stop)
  /// so live location points and Bluetooth-driven waypoints have somewhere
  /// to attach to. Null only during the brief permission-check window
  /// before [TrackingNotifier._initialize] inserts the row.
  final int? tripId;

  /// True when no movement >50m was detected in the last 50 minutes —
  /// the UI shows a "Trip will auto-stop in 10 minutes" warning banner.
  final bool isInactivityWarning;

  /// True only when the trip was stopped by the 60-min inactivity timer,
  /// not by the user pressing stop. The tracking screen uses this to
  /// distinguish auto-stop (show the "60 min" snackbar) from manual stop
  /// (let _handleStop's own snackbar fire instead).
  final bool isAutoStopped;

  factory TrackingViewState.initial() => TrackingViewState(
        status: TrackingStatus.requestingPermission,
        currentPosition: null,
        routePoints: const [],
        pauseWaypoints: const [],
        currentSpeedKmh: 0,
        maxSpeedKmh: 0,
        totalDistanceKm: 0,
        elapsedSeconds: 0,
        startTimeMs: DateTime.now().millisecondsSinceEpoch,
        tripId: null,
        isInactivityWarning: false,
      );

  TrackingViewState copyWith({
    TrackingStatus? status,
    LatLng? currentPosition,
    List<LatLng>? routePoints,
    List<LatLng>? pauseWaypoints,
    double? currentSpeedKmh,
    double? maxSpeedKmh,
    double? totalDistanceKm,
    int? elapsedSeconds,
    int? startTimeMs,
    int? tripId,
    bool? isInactivityWarning,
    bool? isAutoStopped,
  }) {
    return TrackingViewState(
      status: status ?? this.status,
      currentPosition: currentPosition ?? this.currentPosition,
      routePoints: routePoints ?? this.routePoints,
      pauseWaypoints: pauseWaypoints ?? this.pauseWaypoints,
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      tripId: tripId ?? this.tripId,
      isInactivityWarning: isInactivityWarning ?? this.isInactivityWarning,
      isAutoStopped: isAutoStopped ?? this.isAutoStopped,
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
  Timer? _persistTimer;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<TrackedPoint>? _trackedPointSub;
  StreamSubscription<double>? _speedSub;
  StreamSubscription<double>? _distanceSub;
  bool _disposed = false;
  bool _startCoordsCaptured = false; // set from first raw GPS fix
  bool _startLocationCaptured = false; // set from first accurate tracked point

  // Stored at trip start for use in auto-stop finalization.
  TripType _tripType = TripType.business;
  String _vehicleNumber = '';
  double _vehicleOdometer = 0.0;

  // Inactivity auto-stop flags.
  bool _inactivityWarned = false;
  bool _autoStopped = false;

  // True when this notifier resumed an interrupted trip rather than starting
  // a fresh one. Affects how final distance is calculated in stopAndSave().
  bool _isResumedTrip = false;

  // Distance already recorded (in DB) before the resume — used as a base
  // so the live counter doesn't reset to zero after crash recovery.
  double _resumeBaseDistance = 0.0;

  static const _persistKey = 'active_trip_state';

  // Inactivity thresholds — 50 min warning gives the driver a buffer before
  // the 60 min auto-stop fires. Must stay in sync with TrackingService.kt.
  static const _inactivityWarnSeconds = 3000;  // 50 minutes
  static const _inactivityStopSeconds = 3600;  // 60 minutes

  @override
  TrackingViewState build() {
    _locationService = LocationTrackingService();
    ref.onDispose(() {
      _disposed = true;
      _elapsedTimer?.cancel();
      _persistTimer?.cancel();
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
    final args = PendingTrackingArgs.value;
    PendingTrackingArgs.value = null;

    final access = await _locationService.ensureLocationAccess();
    if (_disposed) return;

    if (access != LocationAccessStatus.granted) {
      state = state.copyWith(status: _statusFor(access));
      return;
    }

    final repository = ref.read(tripRepositoryProvider);
    final vehicleRepository = ref.read(vehicleRepositoryProvider);

    // ── Resume path: restore an interrupted trip ──────────────────────────
    final resumeTripId = args?.resumeTripId;
    if (resumeTripId != null) {
      final existingTrip = await repository.getTripById(resumeTripId);
      if (_disposed) return;

      if (existingTrip != null && existingTrip.isActive) {
        _isResumedTrip = true;
        _tripType = TripType.fromString(existingTrip.tripType);
        _vehicleNumber = existingTrip.vehicleNumber;

        final vehicle = await vehicleRepository.getByPlate(_vehicleNumber);
        if (_disposed) return;
        // Prefer the odometer snapshot captured when the trip originally started
        // over the vehicle's current lastOdometer (which may already include
        // this trip's distance if OdometerManager ran after the crash).
        _vehicleOdometer = existingTrip.odometerStart > 0
            ? existingTrip.odometerStart
            : (vehicle?.lastOdometer ?? 0.0);

        // Use DB-stored distance as the base so the live counter starts
        // from what was already driven, not from zero.
        _resumeBaseDistance = existingTrip.distanceKm;

        // Seed elapsed timer from the original start time so the display
        // doesn't reset to zero after a crash recovery.
        final elapsed = ((DateTime.now().millisecondsSinceEpoch -
                    existingTrip.startTime) /
                1000)
            .round();

        state = state.copyWith(
          status: TrackingStatus.active,
          startTimeMs: existingTrip.startTime,
          tripId: resumeTripId,
          elapsedSeconds: elapsed,
          totalDistanceKm: existingTrip.distanceKm,
        );

        await BackgroundTrackingService.start(
          tripId: resumeTripId,
          startTimeMs: existingTrip.startTime,
        );
        if (_disposed) return;
        await _locationService.start();
        if (_disposed) return;

        _startListeners();
        _startTimers();
        return;
      }
      // Existing trip not found or already finalized — fall through to fresh start.
    }

    // ── Normal start path ─────────────────────────────────────────────────
    //
    // Last-line-of-defense: if a trip is already isActive=true in the DB
    // (e.g. user navigated away without stopping, which disposed this notifier
    // and stopped the native service but did NOT finalize the trip), resume it
    // instead of inserting a second row. This is what prevents the "two trips"
    // bug where isRunning=false (service stopped by dispose) but the trip is
    // still open in the DB.
    final existingActive = await repository.getActiveTrip();
    if (existingActive != null) {
      _isResumedTrip = true;
      _tripType = TripType.fromString(existingActive.tripType);
      _vehicleNumber = existingActive.vehicleNumber;
      final existingVehicle =
          await vehicleRepository.getByPlate(_vehicleNumber);
      if (_disposed) return;
      _vehicleOdometer = existingActive.odometerStart > 0
          ? existingActive.odometerStart
          : (existingVehicle?.lastOdometer ?? 0.0);
      _resumeBaseDistance = existingActive.distanceKm;
      final elapsed =
          ((DateTime.now().millisecondsSinceEpoch - existingActive.startTime) /
                  1000)
              .round();
      state = state.copyWith(
        status: TrackingStatus.active,
        startTimeMs: existingActive.startTime,
        tripId: existingActive.id,
        elapsedSeconds: elapsed,
        totalDistanceKm: existingActive.distanceKm,
      );
      await BackgroundTrackingService.start(
        tripId: existingActive.id,
        startTimeMs: existingActive.startTime,
      );
      if (_disposed) return;
      await _locationService.start();
      if (_disposed) return;
      _startListeners();
      _startTimers();
      return;
    }

    final startTimeMs = DateTime.now().millisecondsSinceEpoch;
    final vehicle = args?.vehicleId != null
        ? await vehicleRepository.getById(args!.vehicleId!)
        : null;
    if (_disposed) return;

    _tripType = args?.tripType ?? TripType.business;
    _vehicleNumber = vehicle?.plateNumber ?? '';
    _vehicleOdometer = vehicle?.lastOdometer ?? 0.0;

    // The trip row is created now, not at stop — live location points and
    // any Bluetooth-driven waypoints need a tripId to attach to throughout
    // the drive, not just once the trip is finalized.
    final tripId = await repository.insertTrip(
      TripsCompanion.insert(
        startTime: startTimeMs,
        isActive: const Value(true),
        tripType: Value(_tripType.value),
        vehicleNumber: Value(_vehicleNumber),
        odometerStart: Value(_vehicleOdometer),
      ),
    );
    if (_disposed) return;

    state = state.copyWith(
      status: TrackingStatus.active,
      startTimeMs: startTimeMs,
      tripId: tripId,
    );

    await BackgroundTrackingService.start(
      tripId: tripId,
      startTimeMs: startTimeMs,
      odometerStart: _vehicleOdometer,
    );
    if (_disposed) return;

    await _locationService.start();
    if (_disposed) return;

    _startListeners();
    _startTimers();
  }

  void _startListeners() {
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
      // For resumed trips: state.totalDistanceKm was seeded with the
      // pre-crash distance from the DB in _initialize, so only update
      // when the new in-memory accumulation plus the base exceeds what
      // we already have (avoids the live counter jumping back to 0).
      final newTotal = _resumeBaseDistance + distanceKm;
      if (newTotal > state.totalDistanceKm) {
        state = state.copyWith(totalDistanceKm: newTotal);
      } else if (!_isResumedTrip) {
        state = state.copyWith(totalDistanceKm: distanceKm);
      }
    });
  }

  void _startTimers() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == TrackingStatus.active) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);

        // Inactivity detection: no movement >50m in 50min → warning;
        // no movement >50m in 60min → auto-stop and save.
        final secondsStationary = _locationService.secondsSinceLastMovement;
        if (secondsStationary >= _inactivityStopSeconds && !_autoStopped) {
          _autoStopped = true;
          unawaited(_autoStop());
        } else if (secondsStationary >= _inactivityWarnSeconds && !_inactivityWarned) {
          _inactivityWarned = true;
          state = state.copyWith(isInactivityWarning: true);
        }
      }
      unawaited(BackgroundTrackingService.updateNotification(
        distanceKm: state.totalDistanceKm,
        elapsedSeconds: state.elapsedSeconds,
      ));
    });

    // Persist trip state to SharedPreferences + DB every 30 seconds so a
    // crash or process kill never loses more than 30 seconds of progress.
    _persistTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_persistTripState());
    });
  }

  /// Saves current trip state to SharedPreferences AND updates the DB record
  /// with the latest distance, so crash recovery can show accurate data.
  Future<void> _persistTripState() async {
    final tripId = state.tripId;
    if (tripId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_persistKey}_trip_id', tripId);
      await prefs.setInt('${_persistKey}_start_time', state.startTimeMs);
      await prefs.setDouble('${_persistKey}_distance', state.totalDistanceKm);
      await prefs.setInt('${_persistKey}_route_points', state.routePoints.length);
      await prefs.setInt('${_persistKey}_elapsed_seconds', state.elapsedSeconds);
    } catch (_) {
      // SharedPreferences failure is non-fatal — DB update below is the
      // more durable record.
    }

    // Also write latest distance to the DB row so the recovery dialog can
    // show accurate data even if SharedPreferences is wiped.
    try {
      await ref.read(tripRepositoryProvider).updateTrip(
            TripsCompanion(
              id: Value(tripId),
              distanceKm: Value(state.totalDistanceKm),
            ),
          );
    } catch (_) {
      // Best-effort — isActive=true is still the primary recovery signal.
    }
  }

  /// Clears persisted trip state from SharedPreferences (call on trip stop).
  static Future<void> clearPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_persistKey}_trip_id');
      await prefs.remove('${_persistKey}_start_time');
      await prefs.remove('${_persistKey}_distance');
      await prefs.remove('${_persistKey}_route_points');
      await prefs.remove('${_persistKey}_elapsed_seconds');
    } catch (_) {
      // Ignore errors
    }
  }

  /// Loads persisted trip state from SharedPreferences. Returns null if no
  /// active trip was persisted. Used on app launch to detect crash recovery.
  static Future<({
    int tripId,
    int startTimeMs,
    double distance,
    int routePoints,
    int elapsedSeconds,
  })?> loadPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tripId = prefs.getInt('${_persistKey}_trip_id');
      final startTime = prefs.getInt('${_persistKey}_start_time');
      final distance = prefs.getDouble('${_persistKey}_distance');
      final routePoints = prefs.getInt('${_persistKey}_route_points');
      final elapsedSeconds = prefs.getInt('${_persistKey}_elapsed_seconds');

      if (tripId == null || startTime == null) return null;

      return (
        tripId: tripId,
        startTimeMs: startTime,
        distance: distance ?? 0.0,
        routePoints: routePoints ?? 0,
        elapsedSeconds: elapsedSeconds ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// Re-attempts the permission/service check — call from a "retry" button
  /// when [TrackingViewState.status] is [TrackingStatus.permissionDenied] or
  /// [TrackingStatus.serviceDisabled].
  Future<void> retry() => _initialize();

  /// Updates the live marker position. Raw fixes can be noisy, so this must
  /// not feed the route polyline — see [_onTrackedPoint].
  ///
  /// Also captures start lat/lng from the very first fix so trips that end
  /// before an accurate point arrives still show coordinates, not "Unknown".
  void _onRawPosition(Position position) {
    state = state.copyWith(
      currentPosition: LatLng(position.latitude, position.longitude),
    );

    if (!_startCoordsCaptured) {
      _startCoordsCaptured = true;
      final tripId = state.tripId;
      if (tripId != null) {
        unawaited(
          ref.read(tripRepositoryProvider).updateTripStartLocation(
            tripId: tripId,
            latitude: position.latitude,
            longitude: position.longitude,
            address: '', // tracked point will overwrite with geocoded address
          ).catchError((_) {}),
        );
      }
    }
  }

  /// Appends a point that passed [LocationTrackingService]'s accuracy
  /// filter to the route — the same points the live/final distance is
  /// computed from, so the drawn route and the distance never disagree.
  /// Also persists it to `location_points` as it arrives (tagged with the
  /// trip row created in [_initialize]) so the route survives even if the
  /// app is killed mid-trip, and so the trip detail map/clustering feature
  /// has real data to render.
  void _onTrackedPoint(TrackedPoint point) {
    state = state.copyWith(
      routePoints: [
        ...state.routePoints,
        LatLng(point.latitude, point.longitude),
      ],
    );

    final tripId = state.tripId;
    if (tripId != null) {
      final repository = ref.read(tripRepositoryProvider);
      unawaited(
        repository.insertLocationPoint(
          LocationPointsCompanion.insert(
            tripId: tripId,
            latitude: point.latitude,
            longitude: point.longitude,
            speedKmh: Value(point.speedKmh),
            accuracyMeters: Value(point.accuracyMeters),
            altitude: Value(point.altitude),
            timestamp: point.timestampMs,
          ),
        ).catchError((_) {}), // best-effort — DB write failure must not crash the tracking loop
      );

      // Best-effort, fire-and-forget — so logs_tab.dart's trip cards have a
      // start address without waiting for the trip to finish. Only the
      // first fix of the trip triggers this.
      if (!_startLocationCaptured) {
        _startLocationCaptured = true;
        unawaited(() async {
          try {
            final address =
                await ReverseGeocoder.lookup(point.latitude, point.longitude);
            if (_disposed) return;
            await repository.updateTripStartLocation(
              tripId: tripId,
              latitude: point.latitude,
              longitude: point.longitude,
              address: address,
            );
          } catch (_) {} // best-effort — geocode or DB failure must not crash tracking
        }());
      }
    }
  }

  /// A snapshot of the live trip for Bluetooth-driven waypoint recording —
  /// see [TrackingSnapshot]. Null if no trip is active yet or no GPS fix
  /// has arrived yet.
  TrackingSnapshot? get currentSnapshot {
    final tripId = state.tripId;
    final position = state.currentPosition;
    if (tripId == null || position == null) return null;
    return TrackingSnapshot(
      tripId: tripId,
      latitude: position.latitude,
      longitude: position.longitude,
      distanceKm: _locationService.calculateTotalDistance(),
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

    final tripId = state.tripId;
    final position = state.currentPosition;
    if (tripId != null && position != null) {
      final distanceKm = _locationService.calculateTotalDistance();
      unawaited(
        ref.read(tripRepositoryProvider).recordPauseWaypoint(
          tripId: tripId,
          latitude: position.latitude,
          longitude: position.longitude,
          distanceKmAtStop: distanceKm,
        ).then((_) {
          if (!_disposed) {
            state = state.copyWith(
              pauseWaypoints: [...state.pauseWaypoints, position],
            );
          }
        }),
      );
    }
  }

  void resume() {
    if (state.status != TrackingStatus.paused) return;
    _locationService.resetInactivityTimer();
    _inactivityWarned = false;
    unawaited(_locationService.resume());
    state = state.copyWith(status: TrackingStatus.active, isInactivityWarning: false);

    final tripId = state.tripId;
    final position = state.currentPosition;
    if (tripId != null && position != null) {
      final distanceKm = _locationService.calculateTotalDistance();
      unawaited(
        ref.read(tripRepositoryProvider).recordResumeWaypoint(
          tripId: tripId,
          latitude: position.latitude,
          longitude: position.longitude,
          distanceKmAtStop: distanceKm,
        ),
      );
    }
  }

  void dismissInactivityWarning() {
    state = state.copyWith(isInactivityWarning: false);
  }

  /// Auto-stops and saves the trip after 60 minutes of no detected movement.
  /// Finalizes with whatever metadata was captured at trip start; the user
  /// can edit classification from the logs screen afterward.
  Future<void> _autoStop() async {
    _elapsedTimer?.cancel();
    _persistTimer?.cancel();
    await _locationService.stop();
    await BackgroundTrackingService.stop();
    await clearPersistedState();
    if (_disposed) return;

    final tripId = state.tripId;
    if (tripId == null) return;

    // Read repos before the state update that triggers screen disposal.
    final repository = ref.read(tripRepositoryProvider);
    final vehicleRepository = ref.read(vehicleRepositoryProvider);

    final distanceKm = await _resolveDistance(repository, tripId);
    if (_disposed) return;

    final endTimeMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = state.elapsedSeconds;
    final avgSpeedKmh =
        elapsedSeconds > 0 ? (distanceKm / elapsedSeconds) * 3600 : 0.0;

    final lastPoint =
        _locationService.points.isNotEmpty ? _locationService.points.last : null;
    final endLat = lastPoint?.latitude ?? state.currentPosition?.latitude;
    final endLng = lastPoint?.longitude ?? state.currentPosition?.longitude;
    final endAddress = endLat != null
        ? await ReverseGeocoder.lookup(endLat, endLng!)
        : '';
    if (_disposed) return;

    final vehicle = await vehicleRepository.getByPlate(_vehicleNumber);
    if (_disposed) return;

    final globalRate = await MileageRateService.getRate();
    if (_disposed) return;

    final effectiveRate = (vehicle != null && vehicle.defaultMileageRate > 0)
        ? vehicle.defaultMileageRate
        : globalRate;

    await repository.finalizeTrip(
      tripId: tripId,
      endTime: endTimeMs,
      distanceKm: distanceKm,
      maxSpeedKmh: _locationService.maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh,
      tripType: _tripType,
      companyName: '',
      vehicleNumber: _vehicleNumber,
      odometerStart: _vehicleOdometer,
      odometerEnd: _vehicleOdometer + distanceKm,
      mileageRate: effectiveRate,
      notes: 'Auto-stopped after 60 minutes of inactivity',
      endLat: endLat,
      endLng: endLng,
      endAddress: endAddress,
    );

    if (!_disposed) {
      state = state.copyWith(
        status: TrackingStatus.stopped,
        totalDistanceKm: distanceKm,
        isAutoStopped: true,
      );
    }
  }

  /// Stops GPS updates and finalizes the trip row created in [_initialize]
  /// via [TripRepository], using the distance recomputed from the full
  /// point list (not the live running total) as the authoritative value.
  /// Odometer start/end are taken from [_vehicleOdometer] captured at trip
  /// start — never from caller-supplied values (see CLAUDE.md odometer rule).
  Future<void> stopAndSave({
    required TripType tripType,
    required String companyName,
    required String vehicleNumber,
    String notes = '',
  }) async {
    _elapsedTimer?.cancel();
    _persistTimer?.cancel();
    await _locationService.stop();
    await BackgroundTrackingService.stop();
    await clearPersistedState();
    if (_disposed) return;

    // Read repos before the state update that may trigger screen disposal.
    final repository = ref.read(tripRepositoryProvider);
    final vehicleRepository = ref.read(vehicleRepositoryProvider);

    final tripId = state.tripId;

    if (tripId == null) {
      // Defensive fallback only — _initialize always creates the row once
      // location access is granted, so this should be unreachable.
      final distanceKm = _locationService.calculateTotalDistance();
      final endTimeMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = state.elapsedSeconds;
      final avgSpeedKmh =
          elapsedSeconds > 0 ? (distanceKm / elapsedSeconds) * 3600 : 0.0;
      state = state.copyWith(
        status: TrackingStatus.stopped,
        totalDistanceKm: distanceKm,
      );
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
          companyName: Value(companyName),
          vehicleNumber: Value(vehicleNumber),
          odometerStart: Value(_vehicleOdometer),
          odometerEnd: Value(_vehicleOdometer + distanceKm),
          mileageRate: Value(effectiveRate),
          notes: Value(notes),
        ),
      );
      return;
    }

    // For a resumed trip the authoritative distance is the sum of ALL
    // persisted location points (pre-crash + post-resume). For a normal
    // trip the in-memory calculation is used, which is identical to
    // summing the DB points but avoids an extra DB round-trip.
    final distanceKm = await _resolveDistance(repository, tripId);
    if (_disposed) return;

    final endTimeMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = state.elapsedSeconds;
    final avgSpeedKmh =
        elapsedSeconds > 0 ? (distanceKm / elapsedSeconds) * 3600 : 0.0;

    state = state.copyWith(
      status: TrackingStatus.stopped,
      totalDistanceKm: distanceKm,
    );

    final vehicle = await vehicleRepository.getByPlate(vehicleNumber);
    final globalRate = await MileageRateService.getRate();
    final effectiveRate = (vehicle != null && vehicle.defaultMileageRate > 0)
        ? vehicle.defaultMileageRate
        : globalRate;

    final lastPoint =
        _locationService.points.isNotEmpty ? _locationService.points.last : null;
    final endLat = lastPoint?.latitude ?? state.currentPosition?.latitude;
    final endLng = lastPoint?.longitude ?? state.currentPosition?.longitude;
    final endAddress = endLat != null
        ? await ReverseGeocoder.lookup(endLat, endLng!)
        : '';

    await repository.finalizeTrip(
      tripId: tripId,
      endTime: endTimeMs,
      distanceKm: distanceKm,
      maxSpeedKmh: _locationService.maxSpeedKmh,
      avgSpeedKmh: avgSpeedKmh,
      tripType: tripType,
      companyName: companyName,
      vehicleNumber: vehicleNumber,
      odometerStart: _vehicleOdometer,
      odometerEnd: _vehicleOdometer + distanceKm,
      mileageRate: effectiveRate,
      notes: notes,
      endLat: endLat,
      endLng: endLng,
      endAddress: endAddress,
    );
  }

  /// Returns the authoritative final distance for this trip.
  ///
  /// For a resumed trip (after a crash) all persisted location points are
  /// summed so pre-crash and post-resume segments are both counted. For a
  /// normal trip the in-memory calculation is used.
  Future<double> _resolveDistance(TripRepository repository, int tripId) async {
    if (_isResumedTrip) {
      final persisted =
          await repository.calculateDistanceFromPersistedPoints(tripId);
      // Fall back to in-memory if DB has no points yet (very early crash).
      return persisted > 0 ? persisted : _locationService.calculateTotalDistance();
    }
    return _locationService.calculateTotalDistance();
  }
}

final trackingNotifierProvider =
    NotifierProvider.autoDispose<TrackingNotifier, TrackingViewState>(
  TrackingNotifier.new,
);
