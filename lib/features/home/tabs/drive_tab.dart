import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../../../data/providers/database_provider.dart';
import '../providers/completed_trips_provider.dart';

class DriveTab extends ConsumerStatefulWidget {
  const DriveTab({super.key});

  @override
  ConsumerState<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends ConsumerState<DriveTab> {
  void _handleStartTrip() {
    context.push(AppRoutes.tracking);
  }

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDate = DateTime(date.year, date.month, date.day);

    if (tripDate == today) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (tripDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  String _formatDuration(int? startMs, int? endMs) {
    if (startMs == null || endMs == null) return 'Unknown';
    final durationMs = endMs - startMs;
    final duration = Duration(milliseconds: durationMs);

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatCost(double distanceKm, double mileageRate) {
    if (mileageRate <= 0) return '€0.00';
    final cost = distanceKm * mileageRate;
    return '€${cost.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final vehiclesDao = ref.watch(vehiclesDaoProvider);
    final completedTrips = ref.watch(completedTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Current vehicle card
              FutureBuilder<Vehicle?>(
                future: vehiclesDao.getDefault(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final vehicle = snapshot.data;
                  if (vehicle == null) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Vehicle Set',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a vehicle in Settings',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.directions_car,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Current Vehicle',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            vehicle.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.plateNumber,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.speed,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Odometer: ${NumberFormat('#,##0').format(vehicle.lastOdometer)} km',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 48),

              // Start Trip button
              SizedBox(
                height: 120,
                child: ElevatedButton(
                  onPressed: _handleStartTrip,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        size: 48,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start Trip',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Last trip summary
              Text(
                'Last Trip',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              completedTrips.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $error'),
                  ),
                ),
                data: (trips) {
                  if (trips.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.route,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Trips Yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start your first trip above',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final lastTrip = trips.first;
                  final tripType = TripType.fromString(lastTrip.tripType);
                  final isBusinessTrip = tripType == TripType.business;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(lastTrip.startTime),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${lastTrip.distanceKm.toStringAsFixed(1)} km',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isBusinessTrip
                                      ? Theme.of(context).colorScheme.primary.withAlpha(30)
                                      : Theme.of(context).colorScheme.secondary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  lastTrip.tripType,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: isBusinessTrip
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Theme.of(context).dividerColor),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _InfoChip(
                                icon: Icons.schedule,
                                label: _formatDuration(lastTrip.startTime, lastTrip.endTime),
                                context: context,
                              ),
                              _InfoChip(
                                icon: Icons.speed,
                                label: lastTrip.avgSpeedKmh > 0
                                    ? '${lastTrip.avgSpeedKmh.toStringAsFixed(0)} km/h'
                                    : 'N/A',
                                context: context,
                              ),
                              _InfoChip(
                                icon: Icons.euro,
                                label: _formatCost(lastTrip.distanceKm, lastTrip.mileageRate),
                                context: context,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.context,
  });

  final IconData icon;
  final String label;
  final BuildContext context;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }
}
