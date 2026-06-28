import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/repository_providers.dart';
import '../../reports/services/report_export_service.dart';
import '../providers/completed_trips_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/profile_provider.dart';
import '../utils/trip_stats.dart';

enum ReportPeriod { monthly, allTime, custom }

final selectedReportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.monthly);

/// Only meaningful when [selectedReportPeriodProvider] is
/// [ReportPeriod.custom] — null until the user picks a range or taps a
/// "previous month" chip.
final selectedDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

enum TripTypeFilter { all, business, personal }

final selectedTripTypeFilterProvider =
    StateProvider<TripTypeFilter>((ref) => TripTypeFilter.all);

/// The last [count] full calendar months, most recent first, excluding the
/// current month (already covered by "This month") — feeds the "Previous
/// months" quick selector.
List<DateTime> _recentMonths(int count) {
  final now = DateTime.now();
  return [
    for (var i = 1; i <= count; i++) DateTime(now.year, now.month - i, 1),
  ];
}

/// One slice of the "by client" donut — a company name for business trips,
/// 'Personal' for personal trips, or 'Other' once [AppConstants.reportTopCompanies]
/// is exceeded.
class _ClientSlice {
  const _ClientSlice(
      {required this.label, required this.km, required this.color});

  final String label;
  final double km;
  final Color color;
}

List<_ClientSlice> _buildClientSlices(List<Trip> trips, AppColors colors) {
  final totals = <String, double>{};
  for (final trip in trips) {
    final isBusiness = TripType.fromString(trip.tripType) == TripType.business;
    final key = isBusiness
        ? (trip.companyName.trim().isEmpty
            ? 'Business'
            : trip.companyName.trim())
        : 'Personal';
    totals[key] = (totals[key] ?? 0) + trip.distanceKm;
  }

  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final palette = [colors.accent, colors.accentSecondary, colors.success];
  var paletteIndex = 0;
  final top = entries.take(AppConstants.reportTopCompanies).toList();
  final rest = entries.skip(AppConstants.reportTopCompanies).toList();

  final slices = <_ClientSlice>[];
  for (final entry in top) {
    final color = entry.key == 'Personal'
        ? colors.personalTag
        : palette[paletteIndex++ % palette.length];
    slices.add(_ClientSlice(label: entry.key, km: entry.value, color: color));
  }
  if (rest.isNotEmpty) {
    final otherKm = rest.fold<double>(0, (sum, e) => sum + e.value);
    slices.add(
        _ClientSlice(label: 'Other', km: otherKm, color: colors.textGhost));
  }
  return slices;
}

/// Per-day distance totals for a fixed 5-week (Mon–Sun) window ending on the
/// current week — [AppConstants.heatmapCells] cells, independent of calendar
/// month boundaries so the grid always lines up under the weekday headers.
List<double> _heatmapWindowTotals(List<Trip> trips) {
  final today = DateTime.now();
  final todayDateOnly = DateTime(today.year, today.month, today.day);
  final mondayThisWeek = todayDateOnly
      .subtract(Duration(days: todayDateOnly.weekday - DateTime.monday));
  const weeks = AppConstants.heatmapCells ~/ 7;
  final gridStart =
      mondayThisWeek.subtract(const Duration(days: (weeks - 1) * 7));

  final totals = List<double>.filled(AppConstants.heatmapCells, 0);
  for (final trip in trips) {
    final date = DateTime.fromMillisecondsSinceEpoch(trip.startTime);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final index = dateOnly.difference(gridStart).inDays;
    if (index >= 0 && index < totals.length) {
      totals[index] += trip.distanceKm;
    }
  }
  return totals;
}

class ReportsTab extends ConsumerStatefulWidget {
  const ReportsTab({super.key});

  @override
  ConsumerState<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<ReportsTab> {
  final _exportService = ReportExportService();

  Future<void> _handleExportPDF(
    List<Trip> trips,
    String periodLabel,
    String currency,
    String reportTitle,
    TripTypeFilter typeFilter,
  ) async {
    if (trips.isEmpty) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export PDF'),
        content: const Text('How would you like to export this report?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'share'),
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'download'),
            child: const Text('Download to device'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    try {
      final repo = ref.read(tripRepositoryProvider);
      final waypointResults = await Future.wait(
        trips.map((t) => repo.getWaypointsForTrip(t.id)),
      );
      final locationResults = await Future.wait(
        trips.map((t) => repo.getLocationPointsForTrip(t.id)),
      );
      final waypointsMap = {
        for (var i = 0; i < trips.length; i++) trips[i].id: waypointResults[i],
      };
      final locationMap = {
        for (var i = 0; i < trips.length; i++)
          trips[i].id: locationResults[i],
      };
      if (!mounted) return;
      final profile = ref.read(profileProvider);
      final filterType = switch (typeFilter) {
        TripTypeFilter.all => 'all',
        TripTypeFilter.business => 'business',
        TripTypeFilter.personal => 'personal',
      };
      final result = await _exportService.generatePdf(
        trips: trips,
        periodLabel: periodLabel,
        reportTitle: reportTitle,
        currency: currency,
        filterType: filterType,
        waypoints: waypointsMap,
        locationPoints: locationMap,
        profileName: profile.companyName.isNotEmpty
            ? profile.companyName
            : profile.name,
        profileAddress: profile.address,
        profilePhone: profile.phone,
        profileEmail: profile.email ?? '',
      );
      if (!mounted) return;
      if (action == 'download') {
        final ok =
            await _exportService.downloadToDevice(result.filename, result.bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            ok
                ? 'Saved to Downloads/${result.filename}'
                : 'Download failed — sharing instead',
          ),
        ));
        if (!ok) await _exportService.shareFile(result.filename, result.bytes);
      } else {
        await _exportService.shareFile(result.filename, result.bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('PDF export failed: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  Future<void> _handleExportCSV(List<Trip> trips) async {
    if (trips.isEmpty) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export CSV'),
        content: const Text('How would you like to export this data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'share'),
            child: const Text('Share'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'download'),
            child: const Text('Download to device'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    try {
      final result = await _exportService.generateCsv(trips: trips);
      if (!mounted) return;
      if (action == 'download') {
        final ok =
            await _exportService.downloadToDevice(result.filename, result.bytes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            ok
                ? 'Saved to Downloads/${result.filename}'
                : 'Download failed — sharing instead',
          ),
        ));
        if (!ok) await _exportService.shareFile(result.filename, result.bytes);
      } else {
        await _exportService.shareFile(result.filename, result.bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('CSV export failed: $e'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  List<Trip> _filterTripsByPeriod(
    List<Trip> trips,
    ReportPeriod period,
    DateTimeRange? range,
  ) {
    switch (period) {
      case ReportPeriod.allTime:
        return trips;
      case ReportPeriod.monthly:
        return tripsInCurrentMonth(trips);
      case ReportPeriod.custom:
        if (range == null) return const [];
        final startMs =
            DateTime(range.start.year, range.start.month, range.start.day)
                .millisecondsSinceEpoch;
        final endMs = DateTime(range.end.year, range.end.month,
                range.end.day, 23, 59, 59, 999)
            .millisecondsSinceEpoch;
        return trips
            .where((t) => t.startTime >= startMs && t.startTime <= endMs)
            .toList();
    }
  }

  List<Trip> _filterTripsByType(List<Trip> trips, TripTypeFilter filter) {
    switch (filter) {
      case TripTypeFilter.all:
        return trips;
      case TripTypeFilter.business:
        return trips
            .where((t) =>
                TripType.fromString(t.tripType) == TripType.business)
            .toList();
      case TripTypeFilter.personal:
        return trips
            .where((t) =>
                TripType.fromString(t.tripType) == TripType.personal)
            .toList();
    }
  }

  String _periodLabel(
    ReportPeriod period,
    List<Trip> allTrips,
    DateTimeRange? range,
  ) {
    switch (period) {
      case ReportPeriod.monthly:
        return DateFormat('MMM yyyy').format(DateTime.now()).toUpperCase();
      case ReportPeriod.custom:
        if (range == null) return 'CUSTOM PERIOD';
        final fmt = DateFormat('MMM d, y');
        return '${fmt.format(range.start)} - ${fmt.format(range.end)}'
            .toUpperCase();
      case ReportPeriod.allTime:
        if (allTrips.isEmpty) return 'ALL TIME';
        var earliest = allTrips.first.startTime;
        for (final trip in allTrips) {
          if (trip.startTime < earliest) earliest = trip.startTime;
        }
        final date = DateTime.fromMillisecondsSinceEpoch(earliest);
        return 'SINCE ${DateFormat('MMM yyyy').format(date).toUpperCase()}';
    }
  }

  void _handleSelectPeriod(ReportPeriod period) {
    ref.read(selectedReportPeriodProvider.notifier).state = period;
    if (period == ReportPeriod.custom &&
        ref.read(selectedDateRangeProvider) == null) {
      _handlePickDateRange();
    }
  }

  Future<void> _handlePickDateRange() async {
    final now = DateTime.now();
    final current = ref.read(selectedDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      initialDateRange: current ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) {
      ref.read(selectedDateRangeProvider.notifier).state = picked;
    }
  }

  void _handlePickMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    ref.read(selectedDateRangeProvider.notifier).state =
        DateTimeRange(start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selectedPeriod = ref.watch(selectedReportPeriodProvider);
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final isMonthly = selectedPeriod == ReportPeriod.monthly;
    final isCustom = selectedPeriod == ReportPeriod.custom;
    final completedTrips = ref.watch(completedTripsProvider);
    final currency = ref.watch(currencyCodeProvider);
    final typeFilter = ref.watch(selectedTripTypeFilterProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: completedTrips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (allTrips) {
            final periodFilteredTrips =
                _filterTripsByPeriod(allTrips, selectedPeriod, selectedRange);
            final filteredTrips =
                _filterTripsByType(periodFilteredTrips, typeFilter);
            final reportTitle = switch (typeFilter) {
              TripTypeFilter.all => 'ALL TRIPS',
              TripTypeFilter.business => 'BUSINESS TRIPS',
              TripTypeFilter.personal => 'PERSONAL TRIPS',
            };
            final stats = filteredTrips.isEmpty
                ? TripStats.empty
                : TripStats.fromTrips(filteredTrips);
            final periodLabel =
                _periodLabel(selectedPeriod, allTrips, selectedRange);
            final awaitingRange = isCustom && selectedRange == null;

            return ListView(
              padding: EdgeInsets.only(
                bottom: AppTheme.space24 +
                    MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _Header(periodLabel: periodLabel),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    0,
                    AppTheme.space16,
                    AppTheme.space14,
                  ),
                  child: _RangeToggle(
                    period: selectedPeriod,
                    onChanged: _handleSelectPeriod,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    0,
                    AppTheme.space16,
                    AppTheme.space14,
                  ),
                  child: _TypeFilterRow(
                    filter: typeFilter,
                    onChanged: (f) => ref
                        .read(selectedTripTypeFilterProvider.notifier)
                        .state = f,
                  ),
                ),
                if (isCustom)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.space16,
                      0,
                      AppTheme.space16,
                      AppTheme.space14,
                    ),
                    child: _CustomRangeControls(
                      range: selectedRange,
                      onPickRange: _handlePickDateRange,
                      onPickMonth: _handlePickMonth,
                    ),
                  ),
                if (awaitingRange)
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: AppTheme.space16),
                    child: _PickRangePromptCard(),
                  )
                else if (filteredTrips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16),
                    child: _EmptyReportsCard(isMonthly: isMonthly),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16),
                    child: _TotalDrivenCard(stats: stats, currency: currency),
                  ),
                  if (isMonthly) ...[
                    const _SectionLabel(title: 'DAILY ACTIVITY'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.space16,
                        0,
                        AppTheme.space16,
                        AppTheme.space8,
                      ),
                      child: _HeatmapCard(
                        daily: _heatmapWindowTotals(allTrips),
                      ),
                    ),
                  ],
                  const _SectionLabel(title: 'BY CLIENT'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16),
                    child: _ClientCard(
                        slices: _buildClientSlices(filteredTrips, colors)),
                  ),
                ],
                const _SectionLabel(title: 'EXPORT'),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppTheme.space16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ExportButton(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'PDF',
                          sub: 'Tax-ready',
                          enabled: filteredTrips.isNotEmpty,
                          onTap: () => _handleExportPDF(
                              filteredTrips, periodLabel, currency, reportTitle, typeFilter),
                        ),
                      ),
                      const SizedBox(width: AppTheme.space10),
                      Expanded(
                        child: _ExportButton(
                          icon: Icons.table_chart_outlined,
                          label: 'CSV',
                          sub: 'Spreadsheet',
                          enabled: filteredTrips.isNotEmpty,
                          onTap: () => _handleExportCSV(filteredTrips),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space14,
        AppTheme.space20,
        AppTheme.space10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(periodLabel, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppTheme.space4),
          Text('Reports', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.period, required this.onChanged});

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RangeToggleButton(
              label: 'This month',
              selected: period == ReportPeriod.monthly,
              onTap: () => onChanged(ReportPeriod.monthly),
            ),
          ),
          Expanded(
            child: _RangeToggleButton(
              label: 'All time',
              selected: period == ReportPeriod.allTime,
              onTap: () => onChanged(ReportPeriod.allTime),
            ),
          ),
          Expanded(
            child: _RangeToggleButton(
              label: 'Custom',
              selected: period == ReportPeriod.custom,
              onTap: () => onChanged(ReportPeriod.custom),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only when [ReportPeriod.custom] is selected — a row that opens the
/// native date-range picker, plus a horizontal "previous months" quick
/// selector (May 2026, April 2026, ...) for the common case of "just last
/// month's report" without fighting the calendar picker.
class _CustomRangeControls extends StatelessWidget {
  const _CustomRangeControls({
    required this.range,
    required this.onPickRange,
    required this.onPickMonth,
  });

  final DateTimeRange? range;
  final VoidCallback onPickRange;
  final ValueChanged<DateTime> onPickMonth;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final months = _recentMonths(12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onPickRange,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space14,
              vertical: AppTheme.space14,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range_outlined, color: colors.accent, size: 20),
                const SizedBox(width: AppTheme.space10),
                Expanded(
                  child: Text(
                    range == null
                        ? 'Choose a date range'
                        : '${DateFormat('MMM d, y').format(range!.start)} – '
                            '${DateFormat('MMM d, y').format(range!.end)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textDimmer),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Text('PREVIOUS MONTHS', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppTheme.space8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: months.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppTheme.space8),
            itemBuilder: (context, index) {
              final month = months[index];
              final selected = range != null &&
                  range!.start.year == month.year &&
                  range!.start.month == month.month;
              return _MonthChip(
                label: DateFormat('MMM yyyy').format(month),
                selected: selected,
                onTap: () => onPickMonth(month),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space14),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : colors.surfaceElevated,
          border: Border.all(color: selected ? colors.accent : colors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? colors.accent : colors.textDim,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

class _PickRangePromptCard extends StatelessWidget {
  const _PickRangePromptCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          children: [
            Icon(Icons.date_range_outlined, size: 40, color: colors.textGhost),
            const SizedBox(height: AppTheme.space14),
            Text('Pick a date range',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Choose dates above or tap a previous month',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeToggleButton extends StatelessWidget {
  const _RangeToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space10),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? colors.accent : colors.textDim,
              ),
        ),
      ),
    );
  }
}

class _TotalDrivenCard extends StatelessWidget {
  const _TotalDrivenCard({required this.stats, required this.currency});

  final TripStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final avgRate = stats.businessDistance > 0
        ? stats.businessCost / stats.businessDistance
        : AppConstants.defaultMileageRate;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TOTAL DRIVEN', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: AppTheme.space10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  stats.totalDistance.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(width: AppTheme.space8),
                Text('km',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: colors.textDim)),
              ],
            ),
            const SizedBox(height: AppTheme.space18),
            const _DashedDivider(),
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.space16),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      label: 'BUSINESS',
                      value: stats.businessDistance.toStringAsFixed(1),
                      unit: 'km',
                      accent: true,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'PERSONAL',
                      value: stats.personalDistance.toStringAsFixed(1),
                      unit: 'km',
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      label: 'TRIPS',
                      value: '${stats.totalTrips}',
                      unit: '',
                    ),
                  ),
                ],
              ),
            ),
            if (stats.businessCost > 0) ...[
              const SizedBox(height: AppTheme.space14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space14,
                  vertical: AppTheme.space10,
                ),
                decoration: BoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REIMBURSABLE',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.accent),
                        ),
                        Text(
                          '${stats.businessCost.toStringAsFixed(2)} $currency',
                          style:
                              Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: colors.accent,
                                  ),
                        ),
                      ],
                    ),
                    Text(
                      '@ ${avgRate.toStringAsFixed(2)}\n$currency/KM',
                      textAlign: TextAlign.right,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: colors.accent),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.unit,
    this.accent = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppTheme.space4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: accent ? colors.accent : colors.textPrimary,
                  ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: AppTheme.space4),
              Text(unit,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colors.textDimmer)),
            ],
          ],
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter:
            _DashedDividerPainter(color: AppColors.of(context).borderStrong),
      ),
    );
  }
}

class _DashedDividerPainter extends CustomPainter {
  _DashedDividerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, 0), Offset(math.min(x + dash, size.width), 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space8,
      ),
      child: Text(title, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.daily});

  final List<double> daily;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxValue = daily.fold<double>(0, math.max);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space18),
        child: Column(
          children: [
            Row(
              children: [
                for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space10),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppTheme.space4,
              crossAxisSpacing: AppTheme.space4,
              children: [
                for (final value in daily)
                  _HeatCell(
                    intensity:
                        maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0,
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space10),
            Row(
              children: [
                Text('LESS', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: AppTheme.space8),
                for (final alpha in const [0.2, 0.4, 0.6, 0.8, 1.0])
                  Padding(
                    padding: const EdgeInsets.only(right: AppTheme.space4),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: alpha),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                const SizedBox(width: AppTheme.space4),
                Text('MORE', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasValue = intensity > 0;
    return Container(
      decoration: BoxDecoration(
        color: hasValue
            ? colors.accent.withValues(alpha: 0.2 + intensity * 0.8)
            : colors.surfaceInset,
        border: hasValue ? null : Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.slices});

  final List<_ClientSlice> slices;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DonutChart(slices: slices),
            const SizedBox(width: AppTheme.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final slice in slices)
                    _ClientLegendRow(slice: slice, total: _total),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _total => slices.fold<double>(0, (sum, s) => sum + s.km);
}

class _ClientLegendRow extends StatelessWidget {
  const _ClientLegendRow({required this.slice, required this.total});

  final _ClientSlice slice;
  final double total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (slice.km / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: slice.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text('$pct%', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.slices});

  final List<_ClientSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, s) => sum + s.km);
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(104, 104),
            painter: _DonutPainter(
              slices: slices,
              backgroundColor: AppColors.of(context).surfaceInset,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('TOTAL', style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: AppTheme.space4),
              Text(
                total.toStringAsFixed(0),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.slices, required this.backgroundColor});

  final List<_ClientSlice> slices;
  final Color backgroundColor;

  static const _strokeWidth = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );

    final total = slices.fold<double>(0, (sum, s) => sum + s.km);
    if (total <= 0) return;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.km / total) * 2 * math.pi;
      canvas.drawArc(
        rect,
        startAngle,
        sweep,
        false,
        Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.backgroundColor != backgroundColor;
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.space14),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: colors.accent, size: 18),
              ),
              const SizedBox(height: AppTheme.space8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.space4),
              Text(sub, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeFilterRow extends StatelessWidget {
  const _TypeFilterRow({required this.filter, required this.onChanged});

  final TripTypeFilter filter;
  final ValueChanged<TripTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RangeToggleButton(
              label: 'All Trips',
              selected: filter == TripTypeFilter.all,
              onTap: () => onChanged(TripTypeFilter.all),
            ),
          ),
          Expanded(
            child: _RangeToggleButton(
              label: 'Business',
              selected: filter == TripTypeFilter.business,
              onTap: () => onChanged(TripTypeFilter.business),
            ),
          ),
          Expanded(
            child: _RangeToggleButton(
              label: 'Personal',
              selected: filter == TripTypeFilter.personal,
              onTap: () => onChanged(TripTypeFilter.personal),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReportsCard extends StatelessWidget {
  const _EmptyReportsCard({required this.isMonthly});

  final bool isMonthly;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          children: [
            Icon(Icons.assessment_outlined, size: 40, color: colors.textGhost),
            const SizedBox(height: AppTheme.space14),
            Text(
              isMonthly ? 'No trips this month' : 'No trips yet',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              isMonthly
                  ? 'Start tracking trips to see monthly reports'
                  : 'Start your first trip to see reports',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
