import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/trip_type.dart';
import '../providers/tracking_notifier.dart';
import '../providers/tracking_screen_args.dart';
import '../providers/trip_recovery_provider.dart';

/// Shows when an interrupted trip is detected on app launch.
///
/// Offers two options:
/// - Continue → resume GPS tracking against the existing trip row
/// - Stop & Save → finalize the trip with whatever data is already in the DB
class TripRecoveryDialog extends ConsumerWidget {
  const TripRecoveryDialog({
    required this.tripId,
    required this.startTimeMs,
    required this.distanceKm,
    super.key,
  });

  final int tripId;
  final int startTimeMs;
  final double distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final startTime = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
    final formattedTime = DateFormat('MMM d, h:mm a').format(startTime);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.warning, size: 28),
          const SizedBox(width: AppTheme.space10),
          const Expanded(child: Text('Active Trip Found')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking was interrupted. Would you like to continue this trip or stop and save it now?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppTheme.space16),
          _InfoRow(
            icon: Icons.access_time_outlined,
            label: 'Started',
            value: formattedTime,
          ),
          const SizedBox(height: AppTheme.space8),
          _InfoRow(
            icon: Icons.route_outlined,
            label: 'Distance',
            value: '${distanceKm.toStringAsFixed(1)} km',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await ref
                .read(tripRecoveryProvider.notifier)
                .finalizeAndStopTrip();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Stop & Save'),
        ),
        FilledButton(
          onPressed: () {
            // Pass the existing tripId so TrackingNotifier skips insertTrip
            // and resumes against the same DB row.
            PendingTrackingArgs.value = TrackingScreenArgs(
              tripType: TripType.business,
              resumeTripId: tripId,
            );
            ref.read(tripRecoveryProvider.notifier).markAsResumed();
            Navigator.of(context).pop();
            context.go(AppRoutes.tracking);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textDim),
        const SizedBox(width: AppTheme.space8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textDim,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
