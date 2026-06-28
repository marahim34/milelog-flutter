import 'package:flutter_test/flutter_test.dart';
import 'package:goodo/data/database/app_database.dart';
import 'package:goodo/features/trips/utils/trip_stop_detector.dart';

LocationPoint _point({
  required double lat,
  required double lng,
  required int timestampMs,
}) {
  return LocationPoint(
    id: 0,
    tripId: 1,
    latitude: lat,
    longitude: lng,
    speedKmh: 0,
    accuracyMeters: 0,
    altitude: 0,
    timestamp: timestampMs,
    provider: 'gps',
  );
}

void main() {
  const detector = TripStopDetector(radiusMeters: 50, minDwellSeconds: 90);

  test('no stops on a steadily-moving route', () {
    final points = List.generate(
      20,
      (i) => _point(
        lat: 38.0 + i * 0.001,
        lng: -9.0 + i * 0.001,
        timestampMs: i * 10000,
      ),
    );
    expect(detector.detect(points), isEmpty);
  });

  test('detects a single dwell that exceeds minDwellSeconds', () {
    final points = [
      _point(lat: 38.0, lng: -9.0, timestampMs: 0),
      _point(lat: 38.01, lng: -9.01, timestampMs: 30000),
      // Parked here for 5 minutes — well past the 90s threshold.
      _point(lat: 38.02, lng: -9.02, timestampMs: 60000),
      _point(lat: 38.0201, lng: -9.0201, timestampMs: 120000),
      _point(lat: 38.0199, lng: -9.0199, timestampMs: 240000),
      _point(lat: 38.0200, lng: -9.0200, timestampMs: 360000),
      _point(lat: 38.05, lng: -9.05, timestampMs: 420000),
    ];

    final stops = detector.detect(points);
    expect(stops, hasLength(1));
    expect(stops.single.dwell, const Duration(milliseconds: 360000 - 60000));
  });

  test('ignores a short pause shorter than minDwellSeconds', () {
    final points = [
      _point(lat: 38.0, lng: -9.0, timestampMs: 0),
      // Brief red-light style pause — only 30s, under the 90s threshold.
      _point(lat: 38.0001, lng: -9.0001, timestampMs: 30000),
      _point(lat: 38.05, lng: -9.05, timestampMs: 60000),
    ];

    expect(detector.detect(points), isEmpty);
  });

  test('detects multiple distinct stops along one route', () {
    final points = [
      _point(lat: 38.0, lng: -9.0, timestampMs: 0),
      // Stop 1: ~3 minutes.
      _point(lat: 38.01, lng: -9.01, timestampMs: 10000),
      _point(lat: 38.0101, lng: -9.0101, timestampMs: 100000),
      _point(lat: 38.0099, lng: -9.0099, timestampMs: 190000),
      // Travelling between stops.
      _point(lat: 38.03, lng: -9.03, timestampMs: 220000),
      // Stop 2: ~2 minutes, far enough away to be a separate cluster.
      _point(lat: 38.06, lng: -9.06, timestampMs: 250000),
      _point(lat: 38.0601, lng: -9.0601, timestampMs: 310000),
      _point(lat: 38.0599, lng: -9.0599, timestampMs: 370000),
      _point(lat: 38.08, lng: -9.08, timestampMs: 400000),
    ];

    final stops = detector.detect(points);
    expect(stops, hasLength(2));
    expect(stops[0].startTimeMs, 10000);
    expect(stops[1].startTimeMs, 250000);
  });
}
