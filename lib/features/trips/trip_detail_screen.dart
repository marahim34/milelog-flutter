import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/trip_type.dart';
import '../home/home_screen.dart';
import 'providers/trip_detail_provider.dart';
import 'utils/trip_stop_detector.dart';
import 'widgets/trip_widgets.dart';

/// Read-only "Trip details" page — route map, timeline stats, and a
/// read-only classification summary, with a sticky "Edit trip" button that
/// pushes [EditTripScreen]. Matches the bundled `TripDetails` component
/// (decoded from design_handoff_milelog/prototype/MileLog Trip Details.html)
/// — a separate screen, not a modal sheet, since the GPS-verified route is
/// locked evidence and only the classification below it is ever editable.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({required this.tripId, super.key});

  final int tripId;

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return DateFormat('MMM d, y').format(date);
  }

  String _formatTimeWindow(int startMs, int? endMs) {
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    if (endMs == null) return DateFormat('h:mm a').format(start);
    final end = DateTime.fromMillisecondsSinceEpoch(endMs);
    return '${DateFormat('h:mm a').format(start)}–${DateFormat('h:mm a').format(end)}';
  }

  String _formatDuration(int startMs, int? endMs) {
    if (endMs == null) return 'In progress';
    final duration = Duration(milliseconds: endMs - startMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: const Text(
          'Delete this trip? Its recorded route and stops will be '
          'permanently removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(tripDetailProvider(tripId).notifier).deleteTrip();
    if (!context.mounted) return;
    ref.read(selectedTabIndexProvider.notifier).state = 1;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final detailState = ref.watch(tripDetailProvider(tripId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: const Text('Trip details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete trip',
            onPressed: () => _handleDelete(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: detailState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (detail) => _TripDetailBody(
            trip: detail.trip,
            locationPoints: detail.locationPoints,
            waypoints: detail.waypoints,
            dateLabel: _formatDate(detail.trip.startTime),
            timeWindowLabel:
                _formatTimeWindow(detail.trip.startTime, detail.trip.endTime),
            durationLabel:
                _formatDuration(detail.trip.startTime, detail.trip.endTime),
          ),
        ),
      ),
      bottomNavigationBar: detailState.maybeWhen(
        data: (_) => Container(
          padding: EdgeInsets.fromLTRB(
            AppTheme.space14,
            AppTheme.space8,
            AppTheme.space14,
            MediaQuery.of(context).padding.bottom + AppTheme.space8,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: ElevatedButton(
            onPressed: () => context.push(AppRoutes.tripEditPath(tripId)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: AppTheme.space8),
                Text('Edit trip'),
              ],
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _TripDetailBody extends StatefulWidget {
  const _TripDetailBody({
    required this.trip,
    required this.locationPoints,
    required this.waypoints,
    required this.dateLabel,
    required this.timeWindowLabel,
    required this.durationLabel,
  });

  final Trip trip;
  final List<LocationPoint> locationPoints;
  final List<TripWaypoint> waypoints;
  final String dateLabel;
  final String timeWindowLabel;
  final String durationLabel;

  @override
  State<_TripDetailBody> createState() => _TripDetailBodyState();
}

class _TripDetailBodyState extends State<_TripDetailBody> {
  int? _selectedStopIndex;

  String _formatStopTime(int timestampMs) {
    return DateFormat('h:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
  }

  String _formatDwell(Duration dwell) {
    if (dwell.inMinutes >= 1) return '${dwell.inMinutes}m dwell';
    return '${dwell.inSeconds}s dwell';
  }

  String _fallbackLocation(double? lat, double? lng) {
    if (lat == null || lng == null) return 'Unknown location';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  List<_TimelineEntry> _buildTimelineFromWaypoints(
      List<TripWaypoint> pauseWps) {
    final trip = widget.trip;
    final entries = <_TimelineEntry>[
      _TimelineEntry(
        kind: _TimelineKind.start,
        name: trip.startAddress.isNotEmpty
            ? trip.startAddress
            : _fallbackLocation(trip.startLat, trip.startLng),
        timeMs: trip.startTime,
        meta: 'Departure',
        odometerKm: trip.odometerStart > 0 ? trip.odometerStart : null,
      ),
    ];

    double prevDistKm = 0.0;
    for (var i = 0; i < pauseWps.length; i++) {
      final wp = pauseWps[i];
      final segKm = wp.distanceKmAtStop - prevDistKm;
      entries.add(_TimelineEntry(
        kind: _TimelineKind.stop,
        name: wp.address.isNotEmpty
            ? wp.address
            : _fallbackLocation(wp.latitude, wp.longitude),
        timeMs: wp.timestamp,
        meta: 'Stop',
        stopNumber: i + 1,
        odometerKm: trip.odometerStart > 0
            ? trip.odometerStart + wp.distanceKmAtStop
            : null,
        segmentDistanceKm: segKm > 0.01 ? segKm : null,
      ));
      prevDistKm = wp.distanceKmAtStop;
    }

    final finalSegKm = trip.distanceKm - prevDistKm;
    entries.add(_TimelineEntry(
      kind: _TimelineKind.end,
      name: trip.endAddress.isNotEmpty
          ? trip.endAddress
          : _fallbackLocation(trip.endLat, trip.endLng),
      timeMs: trip.endTime ?? trip.startTime,
      meta: 'Arrival',
      odometerKm: trip.odometerEnd > 0 ? trip.odometerEnd : null,
      segmentDistanceKm: finalSegKm > 0.01 ? finalSegKm : null,
    ));
    return entries;
  }

  List<_TimelineEntry> _buildTimelineFromGpsStops(List<TripStop> gpsStops) {
    final trip = widget.trip;
    final entries = <_TimelineEntry>[
      _TimelineEntry(
        kind: _TimelineKind.start,
        name: trip.startAddress.isNotEmpty
            ? trip.startAddress
            : _fallbackLocation(trip.startLat, trip.startLng),
        timeMs: trip.startTime,
        meta: 'Departure',
        odometerKm: trip.odometerStart > 0 ? trip.odometerStart : null,
      ),
    ];

    for (var i = 0; i < gpsStops.length; i++) {
      entries.add(_TimelineEntry(
        kind: _TimelineKind.stop,
        name: 'Stop ${i + 1}',
        timeMs: gpsStops[i].startTimeMs,
        meta: _formatDwell(gpsStops[i].dwell),
        stopNumber: i + 1,
      ));
    }

    entries.add(_TimelineEntry(
      kind: _TimelineKind.end,
      name: trip.endAddress.isNotEmpty
          ? trip.endAddress
          : _fallbackLocation(trip.endLat, trip.endLng),
      timeMs: trip.endTime ?? trip.startTime,
      meta: 'Arrival',
      odometerKm: trip.odometerEnd > 0 ? trip.odometerEnd : null,
    ));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trip = widget.trip;
    final locationPoints = widget.locationPoints;
    final waypoints = widget.waypoints;
    final routePoints = locationPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
    // Real Bluetooth-driven stops take priority over GPS-dwell detection
    // for the text timeline below — they carry an actual address and a
    // precise distance-at-stop rather than an inferred dwell.
    final stops = const TripStopDetector().detect(locationPoints);
    final pauseWaypoints = waypoints.where((w) => w.isPause).toList();
    final stopCount =
        waypoints.isNotEmpty ? pauseWaypoints.length : stops.length;
    final timeline = pauseWaypoints.isNotEmpty
        ? _buildTimelineFromWaypoints(pauseWaypoints)
        : _buildTimelineFromGpsStops(stops);

    final mapOptions = routePoints.isNotEmpty
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(routePoints),
              padding: const EdgeInsets.all(28),
            ),
            minZoom: 5.0,
            maxZoom: 18.0,
          )
        : const MapOptions(
            initialCenter: LatLng(0, 0),
            initialZoom: 5.0,
            minZoom: 5.0,
            maxZoom: 18.0,
          );

    final tripType = TripType.fromString(trip.tripType);
    final isBusiness = tripType == TripType.business;
    final hasOdometer = trip.odometerStart > 0 || trip.odometerEnd > 0;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.space16),
      children: [
        Row(
          children: [
            StatusChip(
                label: 'Captured', color: colors.success, icon: Icons.check),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: Text(
                '${widget.dateLabel} · ${widget.timeWindowLabel}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.textDimmer, letterSpacing: 0.6),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space14),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Container(
            // At least 60% of the screen height so the GPS-verified route
            // is the dominant thing on screen, not an afterthought above
            // the stats/timeline.
            height: MediaQuery.sizeOf(context).height * 0.6,
            decoration: BoxDecoration(border: Border.all(color: colors.border)),
            child: Stack(
              children: [
                FlutterMap(
                  options: mapOptions,
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.milelog.app',
                    ),
                    // Always the full-resolution trace — clustering below
                    // only affects stop markers, never the route line, so
                    // the polyline stays 100% accurate regardless of trip
                    // length.
                    if (routePoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            color: colors.accent,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
                    // BT waypoints: numbered tappable markers that sync
                    // with the timeline highlight below.
                    if (pauseWaypoints.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          for (var i = 0; i < pauseWaypoints.length; i++)
                            Marker(
                              point: LatLng(pauseWaypoints[i].latitude,
                                  pauseWaypoints[i].longitude),
                              width: 28,
                              height: 28,
                              child: GestureDetector(
                                onTap: () => setState(() =>
                                    _selectedStopIndex = _selectedStopIndex ==
                                            i
                                        ? null
                                        : i),
                                child: _numberedStopMarker(
                                    colors, i + 1, _selectedStopIndex == i),
                              ),
                            ),
                        ],
                      ),
                    // GPS stops (fallback): cluster layer when no BT waypoints
                    if (stops.isNotEmpty && pauseWaypoints.isEmpty)
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 34,
                          size: const Size(30, 30),
                          markers: [
                            for (var i = 0; i < stops.length; i++)
                              Marker(
                                point: stops[i].position,
                                width: 28,
                                height: 28,
                                child: GestureDetector(
                                  onTap: () => setState(() =>
                                      _selectedStopIndex =
                                          _selectedStopIndex == i ? null : i),
                                  child: _numberedStopMarker(
                                      colors, i + 1, _selectedStopIndex == i),
                                ),
                              ),
                          ],
                          builder: (context, markers) =>
                              _clusterBadgeMarker(colors, markers.length),
                        ),
                      ),
                    // Start/end render on their own layer, on top of and
                    // never participating in stop clustering — they must
                    // always stay distinct.
                    if (routePoints.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          _endpointMarker(
                              colors, routePoints.first, Icons.trip_origin),
                          if (routePoints.length > 1)
                            _endpointMarker(
                                colors, routePoints.last, Icons.flag),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    color: Colors.white.withValues(alpha: 0.7),
                    child: const Text(
                      '© OpenStreetMap',
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space8,
                      vertical: AppTheme.space4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 11, color: colors.textDim),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          'GPS-VERIFIED',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: colors.textDim, letterSpacing: 0.8),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('● ', style: TextStyle(color: colors.success, fontSize: 11)),
            Expanded(
              child: Text(
                'The recorded route is locked as audit evidence and cannot be edited.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.textDimmer, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space18),
        Text(
          'TIMELINE',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
        ),
        const SizedBox(height: AppTheme.space8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.space14,
            vertical: AppTheme.space14,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          child: Column(
            children: [
              for (var i = 0; i < timeline.length; i++) ...[
                _TimelineRow(
                  entry: timeline[i],
                  isLast: i == timeline.length - 1,
                  timeLabel: _formatStopTime(timeline[i].timeMs),
                  isSelected: _selectedStopIndex != null &&
                      timeline[i].stopNumber != null &&
                      timeline[i].stopNumber! - 1 == _selectedStopIndex,
                  onTap: timeline[i].stopNumber != null
                      ? () => setState(() {
                            final idx = timeline[i].stopNumber! - 1;
                            _selectedStopIndex =
                                _selectedStopIndex == idx ? null : idx;
                          })
                      : null,
                ),
                if (i < timeline.length - 1 &&
                    timeline[i + 1].segmentDistanceKm != null)
                  _SegmentDistanceLabel(
                      km: timeline[i + 1].segmentDistanceKm!),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            Expanded(
              child: StatBox(label: 'STOPS', value: '$stopCount'),
            ),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: StatBox(
                label: 'DISTANCE',
                value: '${trip.distanceKm.toStringAsFixed(1)} km',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Expanded(
                child: StatBox(label: 'DURATION', value: widget.durationLabel)),
            const SizedBox(width: AppTheme.space8),
            Expanded(
              child: StatBox(
                label: 'AVG SPEED',
                value: trip.avgSpeedKmh > 0
                    ? '${trip.avgSpeedKmh.toStringAsFixed(0)} km/h'
                    : 'N/A',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space18),
        Text(
          'CLASSIFICATION',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
        ),
        const SizedBox(height: AppTheme.space8),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              DetailRow(
                icon: isBusiness
                    ? Icons.business_center_outlined
                    : Icons.person_outline,
                label: 'Type',
                value: isBusiness ? 'Business' : 'Personal',
                accent: true,
              ),
              DetailRow(
                icon: Icons.speed_outlined,
                label: 'Odometer',
                value: hasOdometer
                    ? 'Start: ${NumberFormat('#,##0').format(trip.odometerStart.round())} km'
                        '\nEnd:   ${NumberFormat('#,##0').format(trip.odometerEnd.round())} km'
                    : 'Not recorded',
              ),
              DetailRow(
                icon: Icons.business_outlined,
                label: 'Company',
                value: trip.companyName.isEmpty
                    ? 'No company set'
                    : trip.companyName,
                showDivider: false,
              ),
            ],
          ),
        ),
        if (trip.notes.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space18),
          Text(
            'NOTES',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppTheme.space8),
          Text(
            trip.notes,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.textPrimary),
          ),
        ],
        const SizedBox(height: AppTheme.space24),
      ],
    );
  }

  Marker _endpointMarker(AppColors colors, LatLng point, IconData icon) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: colors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: colors.accentInk, width: 2),
        ),
        child: Icon(icon, color: colors.accentInk, size: 18),
      ),
    );
  }

  Widget _numberedStopMarker(AppColors colors, int number, bool selected) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? colors.accent : colors.surfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: colors.accent, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: TextStyle(
          color: selected ? colors.accentInk : colors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// The numbered badge shown when 2+ stops collapse within
  /// [MarkerClusterLayerOptions.maxClusterRadius] pixels of each other.
  Widget _clusterBadgeMarker(AppColors colors, int count) {
    return Container(
      decoration: BoxDecoration(
        color: colors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: colors.accentInk, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: TextStyle(
          color: colors.accentInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _TimelineKind { start, stop, end }

/// One row of the trip's Start → Stops → End timeline — matches the
/// bundled design's `TripStopList` (decoded from design_handoff_milelog/
/// prototype/td_f06d5b42-...js), which always lists the trip's own
/// departure and arrival alongside any real stops, not just the stops.
class _TimelineEntry {
  const _TimelineEntry({
    required this.kind,
    required this.name,
    required this.timeMs,
    required this.meta,
    this.stopNumber,
    this.odometerKm,
    this.segmentDistanceKm,
  });

  final _TimelineKind kind;
  final String name;
  final int timeMs;
  final String meta;
  final int? stopNumber;        // 1-based; matches the numbered map pin
  final double? odometerKm;    // computed odometer reading at this point
  final double? segmentDistanceKm; // distance from the previous entry
}

/// One row: indicator + connector on the left, name/time/meta on the right.
/// Shapes mirror the design 1:1 — ringed circle (start), small dot (stop),
/// rotated-square "teardrop" (end) — connected by a dashed vertical line.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.entry,
    required this.isLast,
    required this.timeLabel,
    this.isSelected = false,
    this.onTap,
  });

  final _TimelineEntry entry;
  final bool isLast;
  final String timeLabel;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 14,
                child: Column(
                  children: [
                    _TimelineIndicator(kind: entry.kind, color: colors.accent),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          constraints: const BoxConstraints(minHeight: 22),
                          child: CustomPaint(
                            painter: _DashedLinePainter(
                              color: colors.accent.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space10),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      bottom: isLast ? 0 : AppTheme.space14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space8),
                          Text(
                            timeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.textDim),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.meta.toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                color: colors.textDimmer,
                                letterSpacing: 0.6),
                      ),
                      if (entry.odometerKm != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${NumberFormat('#,##0').format(entry.odometerKm!.round())} km odometer',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: colors.accent
                                    .withValues(alpha: 0.75),
                                fontSize: 9,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentDistanceLabel extends StatelessWidget {
  const _SegmentDistanceLabel({required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceInset,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: colors.border.withValues(alpha: 0.6)),
            ),
            child: Text(
              '${km.toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textDim,
                    fontSize: 9,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineIndicator extends StatelessWidget {
  const _TimelineIndicator({required this.kind, required this.color});

  final _TimelineKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    switch (kind) {
      case _TimelineKind.start:
        return Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceElevated,
            border: Border.all(color: color, width: 2.5),
          ),
        );
      case _TimelineKind.stop:
        return Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceElevated,
            border: Border.all(color: color, width: 2),
          ),
        );
      case _TimelineKind.end:
        return Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
            ),
          ),
        );
    }
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dashHeight = 4.0;
    const dashSpace = 4.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
