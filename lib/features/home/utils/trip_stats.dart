import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';

/// Aggregated trip stats — shared by the Drive dashboard and Reports tab so
/// the business/personal split and cost math never drift between the two.
class TripStats {
  const TripStats({
    required this.totalDistance,
    required this.totalCost,
    required this.totalTrips,
    required this.businessTrips,
    required this.businessDistance,
    required this.businessCost,
    required this.personalTrips,
    required this.personalDistance,
    required this.personalCost,
  });

  final double totalDistance;
  final double totalCost;
  final int totalTrips;
  final int businessTrips;
  final double businessDistance;
  final double businessCost;
  final int personalTrips;
  final double personalDistance;
  final double personalCost;

  static const empty = TripStats(
    totalDistance: 0,
    totalCost: 0,
    totalTrips: 0,
    businessTrips: 0,
    businessDistance: 0,
    businessCost: 0,
    personalTrips: 0,
    personalDistance: 0,
    personalCost: 0,
  );

  static TripStats fromTrips(List<Trip> trips) {
    double totalDistance = 0;
    double totalCost = 0;
    int businessTrips = 0;
    double businessDistance = 0;
    double businessCost = 0;
    int personalTrips = 0;
    double personalDistance = 0;
    double personalCost = 0;

    for (final trip in trips) {
      final distance = trip.distanceKm;
      final cost = trip.distanceKm * trip.mileageRate;
      final isBusiness =
          TripType.fromString(trip.tripType) == TripType.business;

      totalDistance += distance;
      totalCost += cost;

      if (isBusiness) {
        businessTrips++;
        businessDistance += distance;
        businessCost += cost;
      } else {
        personalTrips++;
        personalDistance += distance;
        personalCost += cost;
      }
    }

    return TripStats(
      totalDistance: totalDistance,
      totalCost: totalCost,
      totalTrips: trips.length,
      businessTrips: businessTrips,
      businessDistance: businessDistance,
      businessCost: businessCost,
      personalTrips: personalTrips,
      personalDistance: personalDistance,
      personalCost: personalCost,
    );
  }
}

/// (startMs, endMs) bounds of the current calendar month.
(int, int) currentMonthRangeMs() {
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  return (
    firstDayOfMonth.millisecondsSinceEpoch,
    lastDayOfMonth.millisecondsSinceEpoch,
  );
}

List<Trip> tripsInCurrentMonth(List<Trip> trips) {
  final (startMs, endMs) = currentMonthRangeMs();
  return trips
      .where((trip) => trip.startTime >= startMs && trip.startTime <= endMs)
      .toList();
}

/// Per-day distance totals for the days elapsed so far in the current
/// calendar month (index 0 = the 1st) — feeds the Drive sparkline and the
/// Reports daily-activity heatmap.
List<double> dailyTotalsForCurrentMonth(List<Trip> monthTrips) {
  final totals = List<double>.filled(DateTime.now().day, 0);
  for (final trip in monthTrips) {
    final day = DateTime.fromMillisecondsSinceEpoch(trip.startTime).day;
    final index = day - 1;
    if (index >= 0 && index < totals.length) {
      totals[index] += trip.distanceKm;
    }
  }
  return totals;
}
