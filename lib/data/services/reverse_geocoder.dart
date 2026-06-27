import 'package:geocoding/geocoding.dart';

/// Best-effort reverse geocoding for waypoint addresses.
///
/// Mirrors the original Kotlin app's `GeocoderHelper.getPlaceName` — a
/// failure (no network, no geocoder on this device, timeout) must never
/// block waypoint recording, so callers always get a string back, empty on
/// failure rather than a thrown exception.
class ReverseGeocoder {
  ReverseGeocoder._();

  static Future<String> lookup(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 5));
      if (placemarks.isEmpty) return '';
      final p = placemarks.first;
      final parts = [p.street, p.locality, p.administrativeArea]
          .where((part) => part != null && part.trim().isNotEmpty)
          .toList();
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }
}
