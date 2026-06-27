import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';

/// Result of a permission/service check, surfaced to the UI so it can show
/// the right prompt (e.g. "open settings" vs "permission denied").
enum LocationAccessStatus {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

/// One filtered GPS sample collected during an active trip.
class TrackedPoint {
  const TrackedPoint({
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.accuracyMeters,
    required this.altitude,
    required this.timestampMs,
  });

  final double latitude;
  final double longitude;
  final double speedKmh;
  final double accuracyMeters;
  final double altitude;
  final int timestampMs;
}

/// Wraps the geolocator position stream for a single trip.
///
/// Mirrors the Android `LocationTrackingService`: points are buffered
/// in-memory while tracking is active, and [distanceStream] reports a
/// running total for live UI display only. The authoritative distance for
/// a finished trip must come from [calculateTotalDistance], which
/// recomputes the sum from the full point list rather than trusting the
/// incremental counter — distance is calculated on stop, not during
/// tracking (see CLAUDE.md), to avoid drift bugs.
class LocationTrackingService {
  StreamSubscription<Position>? _positionSubscription;
  final List<TrackedPoint> _points = [];
  double _totalDistanceKm = 0;

  // Inactivity detection: tracks last time vehicle moved > 50m.
  int _lastMovementTimeMs = 0;
  TrackedPoint? _lastMovementReferencePoint;
  static const _movementThresholdM = 50.0;

  final _positionController = StreamController<Position>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _distanceController = StreamController<double>.broadcast();
  final _trackedPointController = StreamController<TrackedPoint>.broadcast();

  /// Raw position updates — used to move the map camera/marker. Includes
  /// noisy/low-accuracy fixes, so it must not be used to draw the route.
  Stream<Position> get positionStream => _positionController.stream;

  /// Current speed in km/h, derived from the platform's reported speed.
  Stream<double> get speedStream => _speedController.stream;

  /// Running total distance in km. For live display only — see
  /// [calculateTotalDistance] for the authoritative value.
  Stream<double> get distanceStream => _distanceController.stream;

  /// Points that passed the accuracy filter and were appended to [points] —
  /// i.e. exactly the points the route polyline and distance are built from.
  Stream<TrackedPoint> get trackedPointStream => _trackedPointController.stream;

  List<TrackedPoint> get points => List.unmodifiable(_points);

  double get maxSpeedKmh =>
      _points.isEmpty ? 0 : _points.map((p) => p.speedKmh).reduce(math.max);

  /// Seconds elapsed since the last detected movement of >[_movementThresholdM]m.
  /// Returns 0 if tracking hasn't started yet.
  int get secondsSinceLastMovement {
    if (_lastMovementTimeMs == 0) return 0;
    return ((DateTime.now().millisecondsSinceEpoch - _lastMovementTimeMs) / 1000)
        .floor();
  }

  /// Resets the inactivity clock — call when the trip is manually resumed so
  /// the 60-minute window starts fresh rather than from before the pause.
  void resetInactivityTimer() {
    _lastMovementTimeMs = DateTime.now().millisecondsSinceEpoch;
  }

  /// Checks location services and permission, requesting permission if
  /// it hasn't been granted or denied yet. Call this before [start].
  Future<LocationAccessStatus> ensureLocationAccess() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationAccessStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.deniedForever:
        return LocationAccessStatus.permissionDeniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return LocationAccessStatus.granted;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccessStatus.permissionDenied;
    }
  }

  /// Starts a fresh trip: clears any previously buffered points/distance
  /// and begins listening to the position stream.
  Future<void> start() async {
    _points.clear();
    _totalDistanceKm = 0;
    _lastMovementTimeMs = DateTime.now().millisecondsSinceEpoch;
    _lastMovementReferencePoint = null;
    _distanceController.add(0);
    await _listen();
  }

  /// Resumes listening after [pause] without resetting buffered points.
  Future<void> resume() => _listen();

  /// Stops listening to GPS updates while keeping buffered points, so the
  /// trip can be resumed or finalized afterwards.
  Future<void> pause() => _cancelSubscription();

  /// Stops listening to GPS updates. Buffered points remain available via
  /// [points]/[calculateTotalDistance] for saving the trip.
  Future<void> stop() => _cancelSubscription();

  /// Recomputes the total distance in km by summing the Haversine distance
  /// between every consecutive pair of buffered points. This is the value
  /// that must be persisted when a trip ends.
  double calculateTotalDistance() {
    if (_points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < _points.length; i++) {
      total += _haversineKm(
        _points[i - 1].latitude,
        _points[i - 1].longitude,
        _points[i].latitude,
        _points[i].longitude,
      );
    }
    return total;
  }

  Future<void> _listen() async {
    await _cancelSubscription();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.locationMinDistanceM.toInt(),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPosition);
  }

  Future<void> _cancelSubscription() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _onPosition(Position position) {
    _positionController.add(position);

    // Discard noisy fixes from distance/speed accumulation, but still let
    // the map marker follow them above.
    if (position.accuracy > AppConstants.locationAccuracyThresholdM) {
      return;
    }

    final speedKmh = position.speed * 3.6;
    final point = TrackedPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      speedKmh: speedKmh,
      accuracyMeters: position.accuracy,
      altitude: position.altitude,
      timestampMs: position.timestamp.millisecondsSinceEpoch,
    );

    if (_points.isNotEmpty) {
      final last = _points.last;
      _totalDistanceKm += _haversineKm(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
    }

    // Update inactivity reference when vehicle moves more than the threshold.
    final ref = _lastMovementReferencePoint;
    if (ref == null) {
      _lastMovementReferencePoint = point;
    } else {
      final distM = _haversineKm(
            ref.latitude, ref.longitude, point.latitude, point.longitude) *
          1000;
      if (distM > _movementThresholdM) {
        _lastMovementTimeMs = point.timestampMs;
        _lastMovementReferencePoint = point;
      }
    }

    _points.add(point);
    _trackedPointController.add(point);
    _speedController.add(speedKmh);
    _distanceController.add(_totalDistanceKm);
  }

  Future<void> dispose() async {
    await _cancelSubscription();
    await _positionController.close();
    await _speedController.close();
    await _distanceController.close();
    await _trackedPointController.close();
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double degrees) => degrees * (math.pi / 180);
}
