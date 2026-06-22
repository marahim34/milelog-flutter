import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../providers/completed_trips_provider.dart';

class LogsTab extends ConsumerStatefulWidget {
  const LogsTab({super.key});

  @override
  ConsumerState<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<LogsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedTrips = ref.watch(completedTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Logs'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search trips...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                ),
              ),
            ),
            // Trip list
            Expanded(
              child: completedTrips.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error: $error'),
                ),
                data: (trips) {
                  final filteredTrips = _searchQuery.isEmpty
                      ? trips
                      : trips.where((trip) {
                          return trip.companyName.toLowerCase().contains(_searchQuery) ||
                              trip.tripType.toLowerCase().contains(_searchQuery) ||
                              trip.startAddress.toLowerCase().contains(_searchQuery) ||
                              trip.endAddress.toLowerCase().contains(_searchQuery);
                        }).toList();

                  if (filteredTrips.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty ? Icons.route : Icons.search_off,
                            size: 64,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No trips yet'
                                : 'No trips found',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = filteredTrips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TripCard(trip: trip),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDate = DateTime(date.year, date.month, date.day);

    if (tripDate == today) {
      return 'Today • ${DateFormat('h:mm a').format(date)}';
    } else if (tripDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday • ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(date);
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
    final tripType = TripType.fromString(trip.tripType);
    final isBusinessTrip = tripType == TripType.business;
    final displayCompany = trip.companyName.isEmpty
        ? (isBusinessTrip ? 'Business Trip' : 'Personal Trip')
        : trip.companyName;

    return Card(
      child: InkWell(
        onTap: () => context.push(AppRoutes.tripDetailPath(trip.id)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: date and badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(trip.startTime),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      trip.tripType,
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
              const SizedBox(height: 12),
              // Distance and company
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${trip.distanceKm.toStringAsFixed(1)} km',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isBusinessTrip ? Icons.business : Icons.home,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            displayCompany,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    _formatCost(trip.distanceKm, trip.mileageRate),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: Theme.of(context).dividerColor),
              const SizedBox(height: 12),
              // Duration info
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(trip.startTime, trip.endTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
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
