import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/trip_type.dart';
import '../../data/services/background_tracking_service.dart';
import '../trips/widgets/trip_detail_editor_sheet.dart';
import '../vehicles/providers/vehicles_list_provider.dart';
import 'providers/tracking_notifier.dart';
import 'start_trip_sheet.dart';

const _fallbackCenter = LatLng(0, 0);

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({this.args, super.key});

  final TrackingScreenArgs? args;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _lastCenteredPosition;
  StreamSubscription<bool>? _nativePauseSub;
  bool _didSyncPauseState = false;

  @override
  void initState() {
    super.initState();
    // Must be set before this widget's build() first watches
    // trackingNotifierProvider, since that triggers TrackingNotifier.build
    // (and its _initialize) synchronously on first read.
    if (widget.args != null) {
      PendingTrackingArgs.value = widget.args;
    }
    // Receive real-time pause/resume events from notification buttons while
    // this screen is mounted (e.g. user pulls down shade while on this screen).
    _nativePauseSub =
        TrackingStateBridge.pauseChanged.stream.listen(_onNativePauseChanged);
  }

  @override
  void dispose() {
    _nativePauseSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _onNativePauseChanged(bool isPaused) {
    if (!mounted) return;
    final notifier = ref.read(trackingNotifierProvider.notifier);
    if (isPaused) {
      notifier.pause();
    } else {
      notifier.resume();
    }
  }

  // Called once after the notifier reaches TrackingStatus.tracking so we can
  // sync any pause that happened via the notification while this screen wasn't
  // mounted (e.g. user paused, then re-opened the app).
  Future<void> _syncNativePauseState() async {
    if (!Platform.isAndroid || !mounted) return;
    final isPaused = await BackgroundTrackingService.isNativePaused();
    if (mounted && isPaused) {
      ref.read(trackingNotifierProvider.notifier).pause();
    }
  }

  void _maybeRecenter(LatLng? position) {
    if (position == null || position == _lastCenteredPosition) return;
    _lastCenteredPosition = position;
    _mapController.move(position, _mapController.camera.zoom);
  }

  Future<void> _handleStop() async {
    final notifier = ref.read(trackingNotifierProvider.notifier);
    final trackingState = ref.read(trackingNotifierProvider);
    final vehicles = ref.read(vehiclesListProvider).value ?? const <Vehicle>[];
    Vehicle? selectedVehicle;
    for (final vehicle in vehicles) {
      if (vehicle.id == widget.args?.vehicleId) {
        selectedVehicle = vehicle;
        break;
      }
    }

    final liveDistanceKm = trackingState.totalDistanceKm;
    final liveElapsedSeconds = trackingState.elapsedSeconds;
    final startTime =
        DateTime.fromMillisecondsSinceEpoch(trackingState.startTimeMs);
    final avgSpeedKmh = liveElapsedSeconds > 0
        ? (liveDistanceKm / liveElapsedSeconds) * 3600
        : 0.0;

    final result = await showModalBottomSheet<TripDetailEditorResult>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => TripDetailEditorSheet(
        initialTripType: widget.args?.tripType ?? TripType.business,
        initialCompanyName: '',
        initialNotes: '',
        saveLabel: 'Save trip',
        gpsDistanceKm: liveDistanceKm,
        recap: TripRecapData(
          dateLabel: DateFormat('MMM d, y').format(startTime),
          timeWindowLabel: '${DateFormat('h:mm a').format(startTime)} – '
              '${DateFormat('h:mm a').format(DateTime.now())}',
          durationLabel: _formatDuration(liveElapsedSeconds),
          avgSpeedKmh: avgSpeedKmh,
        ),
      ),
    );

    if (result == null) return;

    try {
      await notifier.stopAndSave(
        tripType: result.tripType,
        companyName: result.companyName,
        vehicleNumber: selectedVehicle?.plateNumber ?? '',
        notes: result.notes,
      );
      final distanceKm = ref.read(trackingNotifierProvider).totalDistanceKm;
      final elapsedSeconds = ref.read(trackingNotifierProvider).elapsedSeconds;

      if (mounted) {
        context.go(AppRoutes.home);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip saved: ${distanceKm.toStringAsFixed(1)} km in '
              '${_formatDuration(elapsedSeconds)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.go(AppRoutes.home);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving trip: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${secs}s';
    }
  }

  void _handlePauseToggle(bool isPaused) {
    final notifier = ref.read(trackingNotifierProvider.notifier);
    if (isPaused) {
      notifier.resume();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip resumed'), duration: Duration(seconds: 1)),
      );
    } else {
      notifier.pause();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip paused'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trackingState = ref.watch(trackingNotifierProvider);

    ref.listen(trackingNotifierProvider, (previous, next) {
      _maybeRecenter(next.currentPosition);
      // Auto-stop only: trip finalized by inactivity timer, NOT manual stop.
      // Manual stop is handled by _handleStop() which navigates itself.
      if (previous?.status != TrackingStatus.stopped &&
          next.status == TrackingStatus.stopped &&
          next.isAutoStopped) {
        if (mounted) {
          context.go(AppRoutes.home);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip auto-saved — no movement for 60 minutes'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });

    if (trackingState.status == TrackingStatus.requestingPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Once the notifier has finished initializing and is actively tracking,
    // sync the native pause state exactly once so UI reflects any pause that
    // happened via the notification while this screen wasn't mounted.
    if (!_didSyncPauseState && trackingState.status == TrackingStatus.active) {
      _didSyncPauseState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncNativePauseState());
    }

    if (trackingState.status == TrackingStatus.permissionDenied ||
        trackingState.status == TrackingStatus.serviceDisabled) {
      return _LocationAccessError(status: trackingState.status);
    }

    final isPaused = trackingState.status == TrackingStatus.paused;
    final routePoints = trackingState.routePoints;
    final pauseWaypoints = trackingState.pauseWaypoints;
    final isInactivityWarning = trackingState.isInactivityWarning;
    final mapCenter = trackingState.currentPosition ??
        (routePoints.isNotEmpty ? routePoints.last : _fallbackCenter);
    final tripType = widget.args?.tripType ?? TripType.business;
    final vehicles = ref.watch(vehiclesListProvider).value ?? const <Vehicle>[];
    Vehicle? selectedVehicle;
    for (final vehicle in vehicles) {
      if (vehicle.id == widget.args?.vehicleId) {
        selectedVehicle = vehicle;
        break;
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip is running in background'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 16.0,
                      minZoom: 5.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.aisora.goodo',
                      ),
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
                      if (pauseWaypoints.isNotEmpty)
                        MarkerLayer(
                          markers: [
                            for (final wp in pauseWaypoints)
                              Marker(
                                point: wp,
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colors.warning,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (trackingState.currentPosition != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: trackingState.currentPosition!,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
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
                  if (isInactivityWarning)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: SafeArea(
                        bottom: false,
                        child: Container(
                          margin: const EdgeInsets.all(AppTheme.space14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space14,
                            vertical: AppTheme.space10,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning,
                            borderRadius:
                                BorderRadius.circular(AppTheme.cardRadius),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: AppTheme.space8),
                              Expanded(
                                child: Text(
                                  'Trip will auto-stop in 10 minutes due to inactivity',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => ref
                                    .read(trackingNotifierProvider.notifier)
                                    .dismissInactivityWarning(),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.space14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MapChip(
                            icon: Icons.gps_fixed,
                            label: 'GPS',
                            color: colors.success,
                          ),
                          InkWell(
                            onTap: () => _handlePauseToggle(isPaused),
                            borderRadius: BorderRadius.circular(20),
                            child: _MapChip(
                              icon: isPaused
                                  ? Icons.pause
                                  : Icons.fiber_manual_record,
                              label: isPaused ? 'PAUSED' : 'RECORDING',
                              color: isPaused ? colors.warning : colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppTheme.space14,
                    bottom: AppTheme.space14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space14,
                        vertical: AppTheme.space10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        border: Border.all(color: colors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            trackingState.currentSpeedKmh.toStringAsFixed(0),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: colors.textPrimary),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            'km/h',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.textDim),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                AppTheme.space18,
                AppTheme.space18,
                AppTheme.space18,
                MediaQuery.of(context).padding.bottom + AppTheme.space16,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'TRIP IN PROGRESS · ${tripType == TripType.business ? 'BUSINESS' : 'PERSONAL'}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: colors.textDimmer),
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              trackingState.totalDistanceKm.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(color: colors.textPrimary),
                            ),
                            const SizedBox(width: AppTheme.space8),
                            Text(
                              'km',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: colors.textDim),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatDuration(trackingState.elapsedSeconds),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: colors.textPrimary),
                            ),
                            Text(
                              'ELAPSED',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: colors.textDimmer),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (selectedVehicle != null) ...[
                      const SizedBox(height: AppTheme.space14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space14,
                          vertical: AppTheme.space10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceInset,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.directions_car,
                                size: 16, color: colors.textDim),
                            const SizedBox(width: AppTheme.space8),
                            Expanded(
                              child: Text(
                                selectedVehicle.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: colors.textDim),
                              ),
                            ),
                            Text(
                              selectedVehicle.plateNumber,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colors.textDimmer,
                                    fontFamily: 'monospace',
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.space16),
                    Row(
                      children: [
                        IconButton.outlined(
                          onPressed: () => _handlePauseToggle(isPaused),
                          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(56, 56),
                            side: BorderSide(color: colors.border),
                          ),
                        ),
                        const SizedBox(width: AppTheme.space10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _handleStop,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppTheme.space14),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.stop, size: 18),
                                SizedBox(width: AppTheme.space8),
                                Text('End trip'),
                              ],
                            ),
                          ),
                        ),
                      ],
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


class _LocationAccessError extends ConsumerWidget {
  const _LocationAccessError({required this.status});

  final TrackingStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = status == TrackingStatus.serviceDisabled
        ? 'Location services are turned off. Enable GPS to start tracking.'
        : 'Location permission is required to track trips.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(trackingNotifierProvider.notifier).retry(),
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.space4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
