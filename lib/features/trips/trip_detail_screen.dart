import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/database/app_database.dart';
import '../../data/models/trip_type.dart';
import 'providers/trip_detail_provider.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({required this.tripId, super.key});

  final int tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  String _formatDuration(int? startMs, int? endMs) {
    if (startMs == null || endMs == null) return 'Unknown';
    final duration = Duration(milliseconds: endMs - startMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }

  String _formatCost(double distanceKm, double mileageRate) {
    if (mileageRate <= 0) return '€0.00';
    return '€${(distanceKm * mileageRate).toStringAsFixed(2)}';
  }

  Future<void> _handleEdit(Trip trip) async {
    final result = await showDialog<_EditTripResult>(
      context: context,
      builder: (context) => _EditTripDialog(
        initialTripType: TripType.fromString(trip.tripType),
        initialCompanyName: trip.companyName,
      ),
    );

    if (result == null) return;

    await ref.read(tripDetailProvider(widget.tripId).notifier).updateTripDetails(
          tripType: result.tripType,
          companyName: result.companyName,
        );
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (detail) => _TripDetailBody(
          trip: detail.trip,
          locationPoints: detail.locationPoints,
          formatDate: _formatDate,
          formatDuration: _formatDuration,
          formatCost: _formatCost,
          onEdit: () => _handleEdit(detail.trip),
        ),
      ),
    );
  }
}

class _TripDetailBody extends StatelessWidget {
  const _TripDetailBody({
    required this.trip,
    required this.locationPoints,
    required this.formatDate,
    required this.formatDuration,
    required this.formatCost,
    required this.onEdit,
  });

  final Trip trip;
  final List<LocationPoint> locationPoints;
  final String Function(int) formatDate;
  final String Function(int?, int?) formatDuration;
  final String Function(double, double) formatCost;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final routePoints = locationPoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);

    final mapOptions = routePoints.isNotEmpty
        ? MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(routePoints),
              padding: const EdgeInsets.fromLTRB(40, 120, 40, 280),
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
    final isBusinessTrip = tripType == TripType.business;

    return Stack(
      children: [
        FlutterMap(
          options: mapOptions,
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
            if (routePoints.isNotEmpty)
              MarkerLayer(
                markers: [
                  _endpointMarker(
                    context,
                    routePoints.first,
                    Icons.trip_origin,
                  ),
                  if (routePoints.length > 1)
                    _endpointMarker(
                      context,
                      routePoints.last,
                      Icons.flag,
                    ),
                ],
              ),
          ],
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(178),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: _TripSummarySheet(
            trip: trip,
            isBusinessTrip: isBusinessTrip,
            dateLabel: formatDate(trip.startTime),
            durationLabel: formatDuration(trip.startTime, trip.endTime),
            costLabel: formatCost(trip.distanceKm, trip.mileageRate),
            onEdit: onEdit,
          ),
        ),
      ],
    );
  }

  Marker _endpointMarker(BuildContext context, LatLng point, IconData icon) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _TripSummarySheet extends StatelessWidget {
  const _TripSummarySheet({
    required this.trip,
    required this.isBusinessTrip,
    required this.dateLabel,
    required this.durationLabel,
    required this.costLabel,
    required this.onEdit,
  });

  final Trip trip;
  final bool isBusinessTrip;
  final String dateLabel;
  final String durationLabel;
  final String costLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final displayCompany = trip.companyName.isEmpty
        ? 'No company set'
        : trip.companyName;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit trip',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  displayCompany,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryStat(
                  label: 'DISTANCE',
                  value: '${trip.distanceKm.toStringAsFixed(1)} km',
                  color: Theme.of(context).colorScheme.primary,
                ),
                _SummaryStat(
                  label: 'DURATION',
                  value: durationLabel,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                _SummaryStat(
                  label: 'AVG SPEED',
                  value: trip.avgSpeedKmh > 0
                      ? '${trip.avgSpeedKmh.toStringAsFixed(0)} km/h'
                      : 'N/A',
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                _SummaryStat(
                  label: 'COST',
                  value: costLabel,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _EditTripResult {
  const _EditTripResult({required this.tripType, required this.companyName});

  final TripType tripType;
  final String companyName;
}

class _EditTripDialog extends StatefulWidget {
  const _EditTripDialog({
    required this.initialTripType,
    required this.initialCompanyName,
  });

  final TripType initialTripType;
  final String initialCompanyName;

  @override
  State<_EditTripDialog> createState() => _EditTripDialogState();
}

class _EditTripDialogState extends State<_EditTripDialog> {
  late TripType _tripType;
  late final TextEditingController _companyController;

  @override
  void initState() {
    super.initState();
    _tripType = widget.initialTripType;
    _companyController = TextEditingController(text: widget.initialCompanyName);
  }

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Trip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip type',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Personal'),
                  selected: _tripType == TripType.personal,
                  onSelected: (_) =>
                      setState(() => _tripType = TripType.personal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Business'),
                  selected: _tripType == TripType.business,
                  onSelected: (_) =>
                      setState(() => _tripType = TripType.business),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: 'Company name',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _EditTripResult(
              tripType: _tripType,
              companyName: _companyController.text.trim(),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
