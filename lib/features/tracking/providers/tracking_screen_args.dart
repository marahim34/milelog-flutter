import '../../../data/models/trip_type.dart';

/// Carried through go_router's `extra` from `StartTripSheet` into
/// `TrackingScreen` (and from `BluetoothAutoTrackingController` when it
/// auto-opens the screen for a matched vehicle), then into the stop dialog
/// as its defaults — so the vehicle/type chosen up front doesn't have to be
/// re-picked at stop time.
///
/// Lives in its own file (rather than inside `tracking_screen.dart`) so
/// `tracking_notifier.dart` and `bluetooth_auto_tracking_provider.dart` can
/// reference it without importing the screen widget.
class TrackingScreenArgs {
  const TrackingScreenArgs({
    this.vehicleId,
    required this.tripType,
    this.resumeTripId,
  });

  final int? vehicleId;
  final TripType tripType;

  /// When set, the notifier resumes this existing trip row instead of
  /// inserting a new one. Used by the crash-recovery flow.
  final int? resumeTripId;
}
