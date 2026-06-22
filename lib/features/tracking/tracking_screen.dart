import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'providers/tracking_notifier.dart';

const _fallbackCenter = LatLng(0, 0);

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _lastCenteredPosition;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _maybeRecenter(LatLng? position) {
    if (position == null || position == _lastCenteredPosition) return;
    _lastCenteredPosition = position;
    _mapController.move(position, _mapController.camera.zoom);
  }

  Future<void> _handleStop() async {
    final notifier = ref.read(trackingNotifierProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Trip'),
        content: const Text('Are you sure you want to stop tracking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Stop',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await notifier.stopAndSave();
      final distanceKm = ref.read(trackingNotifierProvider).totalDistanceKm;
      final elapsedSeconds = ref.read(trackingNotifierProvider).elapsedSeconds;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip saved: ${distanceKm.toStringAsFixed(1)} km in '
              '${_formatDuration(elapsedSeconds)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving trip: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingNotifierProvider);

    ref.listen(trackingNotifierProvider, (previous, next) {
      _maybeRecenter(next.currentPosition);
    });

    if (trackingState.status == TrackingStatus.requestingPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (trackingState.status == TrackingStatus.permissionDenied ||
        trackingState.status == TrackingStatus.serviceDisabled) {
      return _LocationAccessError(status: trackingState.status);
    }

    final isPaused = trackingState.status == TrackingStatus.paused;
    final routePoints = trackingState.routePoints;
    final mapCenter = trackingState.currentPosition ??
        (routePoints.isNotEmpty ? routePoints.last : _fallbackCenter);

    return Scaffold(
      body: Stack(
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.milelog.app',
              ),
              if (routePoints.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4,
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
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
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

          // Top overlay with stats
          SafeArea(
            child: Column(
              children: [
                // Header with back button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(178),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _handleStop,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isPaused
                              ? Theme.of(context).colorScheme.error.withAlpha(178)
                              : Theme.of(context).colorScheme.primary.withAlpha(178),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaused ? Icons.pause : Icons.fiber_manual_record,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isPaused ? 'PAUSED' : 'TRACKING',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'SPEED',
                          value: trackingState.currentSpeedKmh.toStringAsFixed(0),
                          unit: 'km/h',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'DISTANCE',
                          value: trackingState.totalDistanceKm.toStringAsFixed(1),
                          unit: 'km',
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'TIME',
                          value: _formatDuration(trackingState.elapsedSeconds),
                          unit: '',
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Bottom control buttons
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(178),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                final notifier =
                                    ref.read(trackingNotifierProvider.notifier);
                                if (isPaused) {
                                  notifier.resume();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Trip resumed'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                } else {
                                  notifier.pause();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Trip paused'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isPaused ? Icons.play_arrow : Icons.pause,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPaused ? 'RESUME' : 'PAUSE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error.withAlpha(178),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _handleStop,
                              borderRadius: BorderRadius.circular(12),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'STOP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(178),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
