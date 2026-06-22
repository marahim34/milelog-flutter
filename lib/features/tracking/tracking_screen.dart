import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/models/trip_type.dart';
import '../../data/providers/database_provider.dart';

// Tracking state providers
final trackingStateProvider = StateProvider<TrackingState>((ref) => TrackingState.active);
final currentSpeedProvider = StateProvider<double>((ref) => 0.0);
final totalDistanceProvider = StateProvider<double>((ref) => 0.0);
final elapsedTimeProvider = StateProvider<int>((ref) => 0); // seconds
final startTimeProvider = StateProvider<int>((ref) => DateTime.now().millisecondsSinceEpoch);
final maxSpeedProvider = StateProvider<double>((ref) => 0.0);

enum TrackingState { active, paused, stopped }

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final MapController _mapController = MapController();
  Timer? _timer;

  // Simulated current location (would be from geolocator in production)
  final LatLng _currentLocation = const LatLng(51.5074, -0.1278); // London
  final List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    // Reset tracking state for new trip
    ref.read(trackingStateProvider.notifier).state = TrackingState.active;
    ref.read(currentSpeedProvider.notifier).state = 0.0;
    ref.read(totalDistanceProvider.notifier).state = 0.0;
    ref.read(elapsedTimeProvider.notifier).state = 0;
    ref.read(startTimeProvider.notifier).state = DateTime.now().millisecondsSinceEpoch;
    ref.read(maxSpeedProvider.notifier).state = 0.0;

    _startTimer();
    _simulateTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final state = ref.read(trackingStateProvider);
      if (state == TrackingState.active) {
        ref.read(elapsedTimeProvider.notifier).state++;

        // Simulate speed changes
        final currentSpeed = ref.read(currentSpeedProvider);
        final newSpeed = (currentSpeed + (timer.tick % 5 - 2) * 2).clamp(0, 120).toDouble();
        ref.read(currentSpeedProvider.notifier).state = newSpeed;

        // Track max speed
        final maxSpeed = ref.read(maxSpeedProvider);
        if (newSpeed > maxSpeed) {
          ref.read(maxSpeedProvider.notifier).state = newSpeed;
        }

        // Simulate distance accumulation (speed in km/h converted to km per second)
        if (newSpeed > 0) {
          final distanceIncrement = newSpeed / 3600; // km per second
          ref.read(totalDistanceProvider.notifier).state += distanceIncrement;
        }
      }
    });
  }

  void _simulateTracking() {
    // Add initial route points for visualization
    _routePoints.add(_currentLocation);
    setState(() {});
  }

  void _handlePause() {
    final currentState = ref.read(trackingStateProvider);
    if (currentState == TrackingState.active) {
      ref.read(trackingStateProvider.notifier).state = TrackingState.paused;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip paused'), duration: Duration(seconds: 1)),
      );
    } else if (currentState == TrackingState.paused) {
      ref.read(trackingStateProvider.notifier).state = TrackingState.active;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip resumed'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<void> _handleStop() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Trip'),
        content: const Text('Are you sure you want to stop tracking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _saveTrip();
            },
            child: Text(
              'Stop',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTrip() async {
    try {
      _timer?.cancel();
      ref.read(trackingStateProvider.notifier).state = TrackingState.stopped;

      // Gather trip data
      final startTime = ref.read(startTimeProvider);
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final distanceKm = ref.read(totalDistanceProvider);
      final elapsedSeconds = ref.read(elapsedTimeProvider);
      final maxSpeed = ref.read(maxSpeedProvider);

      // Calculate average speed (km/h)
      final avgSpeedKmh = elapsedSeconds > 0
          ? (distanceKm / elapsedSeconds) * 3600
          : 0.0;

      // Insert trip into database
      final tripsDao = ref.read(tripsDaoProvider);
      await tripsDao.insertTrip(
        TripsCompanion.insert(
          startTime: startTime,
          endTime: Value(endTime),
          distanceKm: Value(distanceKm),
          maxSpeedKmh: Value(maxSpeed),
          avgSpeedKmh: Value(avgSpeedKmh),
          isActive: const Value(false),
          tripType: Value(TripType.business.value),
          startAddress: const Value(''),
          endAddress: const Value(''),
          companyName: const Value(''),
          vehicleNumber: const Value(''),
          odometerStart: const Value(0.0),
          odometerEnd: const Value(0.0),
          mileageRate: const Value(0.55), // Default rate
          notes: const Value(''),
          isSynced: const Value(false),
          autoStarted: const Value(false),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip saved: ${distanceKm.toStringAsFixed(1)} km in ${_formatDuration(elapsedSeconds)}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop(); // Return to previous screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving trip: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        Navigator.of(context).pop(); // Still navigate back even on error
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
    final trackingState = ref.watch(trackingStateProvider);
    final currentSpeed = ref.watch(currentSpeedProvider);
    final totalDistance = ref.watch(totalDistanceProvider);
    final elapsedTime = ref.watch(elapsedTimeProvider);

    final isPaused = trackingState == TrackingState.paused;

    return Scaffold(
      body: Stack(
        children: [
          // Full-screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.milelog.app',
              ),
              // Route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Current location marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation,
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
                          value: currentSpeed.toStringAsFixed(0),
                          unit: 'km/h',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'DISTANCE',
                          value: totalDistance.toStringAsFixed(1),
                          unit: 'km',
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'TIME',
                          value: _formatDuration(elapsedTime),
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
                              onTap: _handlePause,
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
