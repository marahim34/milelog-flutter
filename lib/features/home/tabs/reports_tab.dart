import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../reports/services/report_export_service.dart';
import '../providers/completed_trips_provider.dart';

enum ReportPeriod { monthly, allTime }

final selectedReportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.monthly);

class _ReportStats {
  final double totalDistance;
  final double totalCost;
  final int totalTrips;
  final int businessTrips;
  final double businessDistance;
  final double businessCost;
  final int personalTrips;
  final double personalDistance;
  final double personalCost;

  const _ReportStats({
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

  static _ReportStats fromTrips(List<Trip> trips) {
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
      final isBusiness = TripType.fromString(trip.tripType) == TripType.business;

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

    return _ReportStats(
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

  static const empty = _ReportStats(
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
}

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  final _exportService = ReportExportService();

  Future<void> _handleExportPDF(List<Trip> trips, String periodLabel) async {
    if (trips.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting PDF...')),
    );
    try {
      final file = await _exportService.exportPdf(
        trips: trips,
        periodLabel: periodLabel,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _handleExportCSV(List<Trip> trips) async {
    if (trips.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting CSV...')),
    );
    try {
      final file = await _exportService.exportCsv(trips: trips);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV export failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  (int, int) _getCurrentMonthRange() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    return (
      firstDayOfMonth.millisecondsSinceEpoch,
      lastDayOfMonth.millisecondsSinceEpoch,
    );
  }

  String _getCurrentMonthName() {
    return DateFormat('MMMM y').format(DateTime.now());
  }

  List<Trip> _filterTripsByPeriod(List<Trip> trips, ReportPeriod period) {
    if (period == ReportPeriod.allTime) {
      return trips;
    }

    final (startMs, endMs) = _getCurrentMonthRange();
    return trips.where((trip) {
      return trip.startTime >= startMs && trip.startTime <= endMs;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPeriod = ref.watch(selectedReportPeriodProvider);
    final isMonthly = selectedPeriod == ReportPeriod.monthly;
    final completedTrips = ref.watch(completedTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: SafeArea(
        child: completedTrips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Error: $error'),
          ),
          data: (allTrips) {
            final filteredTrips = _filterTripsByPeriod(allTrips, selectedPeriod);
            final stats = filteredTrips.isEmpty
                ? _ReportStats.empty
                : _ReportStats.fromTrips(filteredTrips);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Period selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PeriodButton(
                              label: 'This Month',
                              isSelected: isMonthly,
                              onTap: () {
                                ref.read(selectedReportPeriodProvider.notifier).state =
                                    ReportPeriod.monthly;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PeriodButton(
                              label: 'All Time',
                              isSelected: !isMonthly,
                              onTap: () {
                                ref.read(selectedReportPeriodProvider.notifier).state =
                                    ReportPeriod.allTime;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Empty state
                  if (filteredTrips.isEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assessment_outlined,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isMonthly ? 'No Trips This Month' : 'No Trips Yet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isMonthly
                                  ? 'Start tracking trips to see monthly reports'
                                  : 'Start your first trip to see reports',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Summary statistics
                    Text(
                      isMonthly ? _getCurrentMonthName() : 'All Time Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Total distance and cost cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.route,
                            label: 'Total Distance',
                            value: '${stats.totalDistance.toStringAsFixed(1)} km',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.euro,
                            label: 'Total Cost',
                            value: '€${stats.totalCost.toStringAsFixed(2)}',
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Trip count card
                    _StatCard(
                      icon: Icons.list_alt,
                      label: 'Total Trips',
                      value: '${stats.totalTrips} trip${stats.totalTrips == 1 ? '' : 's'}',
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    const SizedBox(height: 24),

                    // Breakdown by type
                    Text(
                      'Breakdown by Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (stats.businessTrips > 0) ...[
                              _BreakdownRow(
                                type: 'BUSINESS',
                                trips: stats.businessTrips,
                                distance: '${stats.businessDistance.toStringAsFixed(1)} km',
                                cost: '€${stats.businessCost.toStringAsFixed(2)}',
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ],
                            if (stats.businessTrips > 0 && stats.personalTrips > 0) ...[
                              const SizedBox(height: 16),
                              Divider(color: Theme.of(context).dividerColor),
                              const SizedBox(height: 16),
                            ],
                            if (stats.personalTrips > 0) ...[
                              _BreakdownRow(
                                type: 'PERSONAL',
                                trips: stats.personalTrips,
                                distance: '${stats.personalDistance.toStringAsFixed(1)} km',
                                cost: '€${stats.personalCost.toStringAsFixed(2)}',
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ],
                            if (stats.businessTrips == 0 && stats.personalTrips == 0)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'No breakdown available',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Export buttons
                    Text(
                      'Export Options',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: () => _handleExportPDF(
                        filteredTrips,
                        isMonthly ? _getCurrentMonthName() : 'All Time Summary',
                      ),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export as PDF'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () => _handleExportCSV(filteredTrips),
                      icon: const Icon(Icons.table_chart),
                      label: const Text('Export as CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Colors.grey,
              ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.type,
    required this.trips,
    required this.distance,
    required this.cost,
    required this.color,
  });

  final String type;
  final int trips;
  final String distance;
  final String cost;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                type,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              '$trips trips',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distance',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  distance,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Cost',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  cost,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
