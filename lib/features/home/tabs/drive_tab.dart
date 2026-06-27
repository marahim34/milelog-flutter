import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/database_provider.dart';
import '../../tracking/start_trip_sheet.dart';
import '../home_screen.dart';
import '../providers/completed_trips_provider.dart';
import '../utils/trip_stats.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class DriveTab extends ConsumerStatefulWidget {
  const DriveTab({super.key});

  @override
  ConsumerState<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends ConsumerState<DriveTab> {
  // null = still checking, true = ok, false = needs fixing
  bool? _batteryOptimizationOk;

  @override
  void initState() {
    super.initState();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) {
      setState(() => _batteryOptimizationOk = true);
      return;
    }
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (mounted) {
      setState(() => _batteryOptimizationOk = status.isGranted);
    }
  }

  Future<void> _requestBatteryOptimization() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _checkBatteryOptimization();
  }

  Future<void> _handleStartTrip() async {
    final args = await showModalBottomSheet<TrackingScreenArgs>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => const StartTripSheet(),
    );
    if (args != null && mounted) {
      context.push(AppRoutes.tracking, extra: args);
    }
  }

  void _handleSeeAllTrips() =>
      ref.read(selectedTabIndexProvider.notifier).state = 1;

  @override
  Widget build(BuildContext context) {
    final vehiclesDao = ref.watch(vehiclesDaoProvider);
    final completedTrips = ref.watch(completedTripsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: completedTrips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (trips) {
            final monthTrips = tripsInCurrentMonth(trips);
            final stats = TripStats.fromTrips(monthTrips);
            final daily = dailyTotalsForCurrentMonth(monthTrips);
            final recentTrips = trips.take(4).toList();

            return ListView(
              padding: EdgeInsets.only(
                bottom: AppTheme.space24 +
                    MediaQuery.of(context).padding.bottom,
              ),
              children: [
                if (_batteryOptimizationOk == false)
                  _BatteryWarningBanner(onAllow: _requestBatteryOptimization),
                _Header(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    AppTheme.space10,
                    AppTheme.space16,
                    0,
                  ),
                  child: _MonthHeroCard(stats: stats, daily: daily),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    AppTheme.space14,
                    AppTheme.space16,
                    0,
                  ),
                  child: _VehicleCard(vehiclesDao: vehiclesDao),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space16,
                    AppTheme.space14,
                    AppTheme.space16,
                    0,
                  ),
                  child: _StartTripButton(onTap: _handleStartTrip),
                ),
                _SectionLabel(
                  title: 'RECENT TRIPS',
                  onSeeAll: trips.isNotEmpty ? _handleSeeAllTrips : null,
                ),
                if (trips.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppTheme.space16),
                    child: _EmptyTripsCard(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space16),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < recentTrips.length; i++)
                            _TripItem(
                              trip: recentTrips[i],
                              showDivider: i != recentTrips.length - 1,
                              onTap: () => context.push(
                                AppRoutes.tripDetailPath(recentTrips[i].id),
                              ),
                            ),
                        ],
                      ),
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
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space14,
        AppTheme.space20,
        AppTheme.space4,
      ),
      child: Row(
        children: [
          Text(
            _greeting().toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _MonthHeroCard extends StatelessWidget {
  const _MonthHeroCard({required this.stats, required this.daily});

  final TripStats stats;
  final List<double> daily;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final monthLabel =
        DateFormat('MMM yyyy').format(DateTime.now()).toUpperCase();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('THIS MONTH · $monthLabel',
                    style: Theme.of(context).textTheme.labelSmall),
                Text(
                  '${stats.totalTrips} trip${stats.totalTrips == 1 ? '' : 's'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textDim),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space14),
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
            if (stats.businessCost > 0) ...[
              const SizedBox(height: AppTheme.space4),
              Row(
                children: [
                  Text('Reimbursable',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDim)),
                  const SizedBox(width: AppTheme.space10),
                  Text(
                    '€${stats.businessCost.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.space18),
            if (daily.length > 1) _Sparkline(values: daily),
            if (stats.businessDistance > 0 || stats.personalDistance > 0) ...[
              const SizedBox(height: AppTheme.space18),
              _SplitBar(
                businessKm: stats.businessDistance,
                personalKm: stats.personalDistance,
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SplitLegend(
                    color: colors.businessTag,
                    label: 'Business',
                    km: stats.businessDistance,
                  ),
                  _SplitLegend(
                    color: colors.personalTag,
                    label: 'Personal',
                    km: stats.personalDistance,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SplitLegend extends StatelessWidget {
  const _SplitLegend(
      {required this.color, required this.label, required this.km});

  final Color color;
  final String label;
  final double km;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.space8),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.textDim)),
        const SizedBox(width: AppTheme.space8),
        Text(
          km.toStringAsFixed(1),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.businessKm, required this.personalKm});

  final double businessKm;
  final double personalKm;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = businessKm + personalKm;
    if (total <= 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(height: 6, color: colors.surfaceInset),
      );
    }
    final bizFlex = (businessKm / total * 1000).round().clamp(1, 999);
    final personalFlex = (1000 - bizFlex).clamp(1, 999);

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
                flex: bizFlex, child: Container(color: colors.businessTag)),
            Expanded(
              flex: personalFlex,
              child:
                  Container(color: colors.personalTag.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: values,
          accentColor: AppColors.of(context).accent,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.accentColor});

  final List<double> values;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = values.fold<double>(1, math.max);
    final stepX = size.width / (values.length - 1);
    final points = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * stepX,
          size.height - (values[i] / maxValue) * (size.height - 6) - 3,
        ),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.25),
          accentColor.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final today = points.last;
    canvas.drawCircle(
        today, 6, Paint()..color = accentColor.withValues(alpha: 0.25));
    canvas.drawCircle(today, 3, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.accentColor != accentColor;
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehiclesDao});

  final VehiclesDao vehiclesDao;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Vehicle?>(
      future: vehiclesDao.getDefault(),
      builder: (context, snapshot) {
        final colors = AppColors.of(context);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(AppTheme.space16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final vehicle = snapshot.data;
        if (vehicle == null) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space16),
              child: Row(
                children: [
                  const _IconBadge(icon: Icons.directions_car_outlined),
                  const SizedBox(width: AppTheme.space14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('No vehicle set',
                            style: Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: AppTheme.space4),
                        Text(
                          'Add a vehicle in Settings',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textDim),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.space16),
            child: Row(
              children: [
                const _IconBadge(icon: Icons.directions_car),
                const SizedBox(width: AppTheme.space14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.name,
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: AppTheme.space4),
                      Text(
                        '${vehicle.plateNumber} · ${NumberFormat('#,##0').format(vehicle.lastOdometer)} km',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.accentTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: colors.accent, size: 24),
    );
  }
}

class _StartTripButton extends StatelessWidget {
  const _StartTripButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 20),
            const SizedBox(width: AppTheme.space10),
            Text(
              'Start trip',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.accentInk,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelSmall),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

class _EmptyTripsCard extends StatelessWidget {
  const _EmptyTripsCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          children: [
            Icon(Icons.route, size: 40, color: colors.textGhost),
            const SizedBox(height: AppTheme.space14),
            Text('No trips yet', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Start your first trip above',
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

class _TripItem extends StatelessWidget {
  const _TripItem({
    required this.trip,
    required this.showDivider,
    required this.onTap,
  });

  final Trip trip;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBusiness = TripType.fromString(trip.tripType) == TripType.business;
    final tagColor = isBusiness ? colors.businessTag : colors.personalTag;
    final title = trip.companyName.isNotEmpty
        ? trip.companyName
        : (isBusiness ? 'Business trip' : 'Personal trip');
    final date = DateTime.fromMillisecondsSinceEpoch(trip.startTime);
    final duration = trip.endTime != null
        ? Duration(milliseconds: trip.endTime! - trip.startTime)
        : null;
    final metaParts = [
      DateFormat('MMM d · HH:mm').format(date),
      if (duration != null) '${duration.inMinutes} min',
    ];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space18,
          vertical: AppTheme.space14,
        ),
        decoration: showDivider
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              )
            : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 9,
                child: Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.textDim, width: 1.8),
                      ),
                    ),
                    Expanded(
                      child: CustomPaint(
                        painter: _DashedLinePainter(color: colors.textGhost),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: tagColor, shape: BoxShape.circle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(metaParts.join(' · '),
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        trip.distanceKm.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: AppTheme.space4),
                      Text('km',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: colors.textDimmer)),
                    ],
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    isBusiness ? 'BUSINESS' : 'PERSONAL',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: tagColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 3.0;
    const gap = 3.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(
          Offset(x, y), Offset(x, math.min(y + dash, size.height)), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Shown on Android when the app has not been excluded from battery
/// optimisation. Tapping "Fix now" opens the system permission dialog.
class _BatteryWarningBanner extends StatelessWidget {
  const _BatteryWarningBanner({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space14,
        AppTheme.space16,
        0,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.battery_alert, color: colors.warning, size: 20),
            const SizedBox(width: AppTheme.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Background activity restricted',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.warning,
                        ),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    'GPS tracking may stop when the screen locks. '
                    'Allow background activity so trips are never interrupted.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textDim,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: AppTheme.space10),
                  TextButton(
                    onPressed: onAllow,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: colors.warning,
                    ),
                    child: const Text('Fix now →'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
