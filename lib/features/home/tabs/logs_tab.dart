import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/trip_type.dart';
import '../providers/completed_trips_provider.dart';
import '../providers/currency_provider.dart';

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
    final colors = AppColors.of(context);
    final completedTrips = ref.watch(completedTripsProvider);
    final currency = ref.watch(currencyCodeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space20,
                AppTheme.space14,
                AppTheme.space20,
                AppTheme.space10,
              ),
              child: Text('Logs', style: Theme.of(context).textTheme.headlineMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space16,
                0,
                AppTheme.space16,
                AppTheme.space10,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search trips…',
                  prefixIcon: Icon(Icons.search, color: colors.textDimmer),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: colors.textDimmer),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: completedTrips.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
                data: (trips) {
                  final filteredTrips = _searchQuery.isEmpty
                      ? trips
                      : trips.where((trip) {
                          return trip.companyName
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              trip.tripType
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              trip.startAddress
                                  .toLowerCase()
                                  .contains(_searchQuery) ||
                              trip.endAddress
                                  .toLowerCase()
                                  .contains(_searchQuery);
                        }).toList();

                  if (filteredTrips.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.route_outlined
                                : Icons.search_off,
                            size: 48,
                            color: colors.textGhost,
                          ),
                          const SizedBox(height: AppTheme.space14),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No trips yet'
                                : 'No trips found',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: colors.textDim),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      AppTheme.space16,
                      0,
                      AppTheme.space16,
                      MediaQuery.of(context).padding.bottom + AppTheme.space24,
                    ),
                    itemCount: filteredTrips.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppTheme.space10),
                        child: _TripCard(
                            trip: filteredTrips[index], currency: currency),
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
  const _TripCard({required this.trip, required this.currency});

  final Trip trip;
  final String currency;

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDate = DateTime(date.year, date.month, date.day);

    if (tripDate == today) {
      return 'Today · ${DateFormat('h:mm a').format(date)}';
    } else if (tripDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday · ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, y · h:mm a').format(date);
    }
  }

  String _formatDuration(int? startMs, int? endMs) {
    if (startMs == null || endMs == null) return 'Unknown';
    final duration = Duration(milliseconds: endMs - startMs);
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _formatCost(double distanceKm, double mileageRate, String currency) {
    if (mileageRate <= 0) return '0.00 $currency';
    return '${(distanceKm * mileageRate).toStringAsFixed(2)} $currency';
  }

  String _formatLocation(String address, double? lat, double? lng) {
    if (address.isNotEmpty) return address;
    if (lat != null && lng != null) {
      return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
    return 'Unknown location';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tripType = TripType.fromString(trip.tripType);
    final isBusiness = tripType == TripType.business;
    final displayCompany = trip.companyName.isEmpty
        ? (isBusiness ? 'Business Trip' : 'Personal Trip')
        : trip.companyName;
    final tagColor = isBusiness ? colors.businessTag : colors.personalTag;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.tripDetailPath(trip.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(trip.startTime),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDim),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppTheme.space8),
                    ),
                    child: Text(
                      trip.tripType,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: tagColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            trip.distanceKm.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: colors.accent),
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            'km',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.textDim),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Icon(
                            isBusiness ? Icons.business_outlined : Icons.home_outlined,
                            size: 13,
                            color: colors.textDimmer,
                          ),
                          const SizedBox(width: AppTheme.space4),
                          Text(
                            displayCompany,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: colors.textDim),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    _formatCost(trip.distanceKm, trip.mileageRate, currency),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space14),
              Container(height: 1, color: colors.border),
              const SizedBox(height: AppTheme.space10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route_outlined, size: 14, color: colors.textDimmer),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      '${_formatLocation(trip.startAddress, trip.startLat, trip.startLng)} '
                      '→ ${_formatLocation(trip.endAddress, trip.endLat, trip.endLng)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDim),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 14, color: colors.textDimmer),
                  const SizedBox(width: AppTheme.space8),
                  Text(
                    _formatDuration(trip.startTime, trip.endTime),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textDim),
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
