import 'package:latlong2/latlong.dart';

import '../../../data/database/app_database.dart';

/// A detected dwell period along a trip's route — GPS stayed within
/// [TripStopDetector.radiusMeters] of the same spot for at least
/// [TripStopDetector.minDwellSeconds]. Distinct from the trip's overall
/// start/end, which are never treated as stops.
class TripStop {
  const TripStop({
    required this.position,
    required this.startTimeMs,
    required this.endTimeMs,
  });

  final LatLng position;
  final int startTimeMs;
  final int endTimeMs;

  Duration get dwell => Duration(milliseconds: endTimeMs - startTimeMs);
}

/// Derives dwell stops from a trip's raw [LocationPoint] trace.
///
/// This is a presentation-layer computation only — it never writes back to
/// the database or runs during tracking (CLAUDE.md: distance/route data is
/// captured once per GPS fix and never reprocessed mid-trip). A long trip
/// can have hundreds of points; this is O(n) and cheap to run each time
/// Trip Details is opened.
class TripStopDetector {
  const TripStopDetector({
    this.radiusMeters = 50,
    this.minDwellSeconds = 90,
  });

  /// How close consecutive points must stay to count as "not moving".
  final double radiusMeters;

  /// Minimum time spent within [radiusMeters] before a dwell counts as a
  /// stop — short red-light pauses are noise, not stops.
  final int minDwellSeconds;

  static const _distance = Distance();

  List<TripStop> detect(List<LocationPoint> points) {
    if (points.length < 2) return const [];
    final stops = <TripStop>[];

    var i = 0;
    while (i < points.length - 1) {
      final anchor = points[i];
      var j = i;
      while (j + 1 < points.length &&
          _distance.as(
                LengthUnit.Meter,
                LatLng(anchor.latitude, anchor.longitude),
                LatLng(points[j + 1].latitude, points[j + 1].longitude),
              ) <=
              radiusMeters) {
        j++;
      }

      final durationMs = points[j].timestamp - points[i].timestamp;
      if (durationMs >= minDwellSeconds * 1000) {
        final run = points.sublist(i, j + 1);
        final avgLat = run.map((p) => p.latitude).reduce((a, b) => a + b) / run.length;
        final avgLng = run.map((p) => p.longitude).reduce((a, b) => a + b) / run.length;
        stops.add(TripStop(
          position: LatLng(avgLat, avgLng),
          startTimeMs: points[i].timestamp,
          endTimeMs: points[j].timestamp,
        ));
        i = j + 1;
      } else {
        i++;
      }
    }
    return stops;
  }
}
