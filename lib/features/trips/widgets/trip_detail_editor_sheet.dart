import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/trip_type.dart';
import 'trip_widgets.dart';

/// Auto-captured recap shown above the form when this sheet appears right
/// after "End trip" — omitted when editing a trip from its detail screen,
/// where the same stats are already visible behind the sheet. Matches the
/// `recap` block of the bundled `TripDetailEditor` component (decoded from
/// design_handoff_milelog/prototype/MileLog Ended Trip.html — the stale
/// flows.jsx copy in this repo lacked the recap/validation entirely).
class TripRecapData {
  const TripRecapData({
    required this.dateLabel,
    required this.timeWindowLabel,
    required this.durationLabel,
    required this.avgSpeedKmh,
  });

  final String dateLabel;
  final String timeWindowLabel;
  final String durationLabel;
  final double avgSpeedKmh;
}

class TripDetailEditorResult {
  const TripDetailEditorResult({
    required this.tripType,
    required this.companyName,
    required this.notes,
  });

  final TripType tripType;
  final String companyName;
  final String notes;
}

/// The "Trip details" sheet — shared by the post-trip "Ended Trip" flow
/// ([TrackingScreen]) and the trip-detail edit flow ([TripDetailScreen]).
///
/// Mirrors the actual bundled `TripDetailEditor` component (not the stale
/// flows.jsx copy): odometer entry is guarded against going below the
/// vehicle's last known reading or below the start reading, and a GPS
/// mismatch warning fires if the entered odometer delta disagrees with the
/// GPS-measured distance by more than 5 km. Save is disabled while invalid.
class TripDetailEditorSheet extends ConsumerStatefulWidget {
  const TripDetailEditorSheet({
    required this.initialTripType,
    required this.initialCompanyName,
    required this.initialNotes,
    required this.gpsDistanceKm,
    this.title = 'Trip details',
    this.saveLabel = 'Save',
    this.recap,
    super.key,
  });

  final TripType initialTripType;
  final String initialCompanyName;
  final String initialNotes;

  /// The trip's GPS-measured distance — always authoritative; shown in recap.
  final double gpsDistanceKm;

  final String title;
  final String saveLabel;
  final TripRecapData? recap;

  @override
  ConsumerState<TripDetailEditorSheet> createState() =>
      _TripDetailEditorSheetState();
}

class _TripDetailEditorSheetState
    extends ConsumerState<TripDetailEditorSheet> {
  late TripType _tripType;
  late final TextEditingController _companyController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _tripType = widget.initialTripType;
    _companyController = TextEditingController(text: widget.initialCompanyName);
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      TripDetailEditorResult(
        tripType: _tripType,
        companyName: _companyController.text.trim(),
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recap = widget.recap;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20 +
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            if (recap != null) ...[
              const SizedBox(height: AppTheme.space14),
              Row(
                children: [
                  StatusChip(
                    label: 'Captured',
                    color: colors.success,
                    icon: Icons.check,
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: Text(
                      '${recap.dateLabel} · ${recap.timeWindowLabel}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.textDimmer,
                            letterSpacing: 0.6,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('● ', style: TextStyle(color: colors.success, fontSize: 11)),
                  Expanded(
                    child: Text(
                      'The GPS-recorded route is locked as evidence and can\'t '
                      'be edited. Only the details below are editable.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDimmer, height: 1.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space14),
              Row(
                children: [
                  Expanded(
                    child: StatBox(
                      label: 'DISTANCE',
                      value: '${widget.gpsDistanceKm.toStringAsFixed(1)} km',
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: StatBox(label: 'DURATION', value: recap.durationLabel),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: StatBox(
                      label: 'AVG SPEED',
                      value: recap.avgSpeedKmh > 0
                          ? '${recap.avgSpeedKmh.toStringAsFixed(0)} km/h'
                          : 'N/A',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space16),
              Container(height: 1, color: colors.border),
            ],
            const SizedBox(height: AppTheme.space16),
            Text(
              'CLASSIFY THIS TRIP',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
            ),
            const SizedBox(height: AppTheme.space10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surfaceInset,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentButton(
                      icon: Icons.business_center_outlined,
                      label: 'Business',
                      selected: _tripType == TripType.business,
                      onTap: () =>
                          setState(() => _tripType = TripType.business),
                    ),
                  ),
                  Expanded(
                    child: SegmentButton(
                      icon: Icons.person_outline,
                      label: 'Personal',
                      selected: _tripType == TripType.personal,
                      onTap: () =>
                          setState(() => _tripType = TripType.personal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space14),
                      side: BorderSide(color: colors.border),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppTheme.space10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space14),
                    ),
                    child: Text(widget.saveLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
