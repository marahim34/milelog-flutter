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
    required this.odometerStart,
    required this.odometerEnd,
    required this.notes,
  });

  final TripType tripType;
  final String companyName;
  final double odometerStart;
  final double odometerEnd;
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
    required this.initialOdometerStart,
    required this.initialOdometerEnd,
    required this.initialNotes,
    required this.gpsDistanceKm,
    this.title = 'Trip details',
    this.saveLabel = 'Save',
    this.recap,
    this.lastOdometerReading,
    super.key,
  });

  final TripType initialTripType;
  final String initialCompanyName;
  final double initialOdometerStart;
  final double initialOdometerEnd;
  final String initialNotes;

  /// The trip's GPS-measured distance — always authoritative (CLAUDE.md:
  /// distance is computed from GPS at stop time, never overridden by the
  /// odometer fields below). Used to flag a mismatch, not to gate saving.
  final double gpsDistanceKm;

  final String title;
  final String saveLabel;
  final TripRecapData? recap;

  /// The vehicle's odometer reading before this trip. When set, the start
  /// field can't be entered below it — the odometer never runs backwards.
  /// Left null when editing a historical trip, since the vehicle's
  /// *current* reading has since advanced past many later trips and is no
  /// longer a valid floor for this one.
  final double? lastOdometerReading;

  @override
  ConsumerState<TripDetailEditorSheet> createState() =>
      _TripDetailEditorSheetState();
}

class _TripDetailEditorSheetState
    extends ConsumerState<TripDetailEditorSheet> {
  late TripType _tripType;
  late final TextEditingController _companyController;
  late final TextEditingController _odoStartController;
  late final TextEditingController _odoEndController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _tripType = widget.initialTripType;
    _companyController = TextEditingController(text: widget.initialCompanyName);
    _odoStartController = TextEditingController(
      text: widget.initialOdometerStart > 0
          ? widget.initialOdometerStart.toStringAsFixed(0)
          : '',
    );
    _odoEndController = TextEditingController(
      text: widget.initialOdometerEnd > 0
          ? widget.initialOdometerEnd.toStringAsFixed(0)
          : '',
    );
    _notesController = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _companyController.dispose();
    _odoStartController.dispose();
    _odoEndController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _odoStart => double.tryParse(_odoStartController.text.trim()) ?? 0;
  double get _odoEnd => double.tryParse(_odoEndController.text.trim()) ?? 0;
  double get _odoKm => (_odoEnd - _odoStart).clamp(0, double.infinity);

  bool get _odometerEntered => _odoStart > 0 || _odoEnd > 0;

  bool get _startTooLow {
    final lastReading = widget.lastOdometerReading;
    if (_odoStart <= 0 || lastReading == null || lastReading <= 0) return false;
    // Compare against the same whole-km rounding the field displays/parses,
    // so a vehicle reading like 9.4 km doesn't falsely flag the "9" the
    // field shows for it as "too low".
    return _odoStart < lastReading.roundToDouble();
  }

  bool get _endTooLow => _odoStart > 0 && _odoEnd > 0 && _odoEnd < _odoStart;

  bool get _valid => !_startTooLow && !_endTooLow;

  bool get _mismatch =>
      _valid &&
      _odoStart > 0 &&
      _odoEnd > 0 &&
      (_odoKm - widget.gpsDistanceKm).abs() > 5;

  void _save() {
    if (!_valid) return;
    Navigator.of(context).pop(
      TripDetailEditorResult(
        tripType: _tripType,
        companyName: _companyController.text.trim(),
        odometerStart: _odoStart,
        odometerEnd: _odoEnd,
        notes: _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final recap = widget.recap;
    final lastReading = widget.lastOdometerReading;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ODOMETER',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
                ),
                if (lastReading != null && lastReading > 0)
                  Text(
                    'Last: ${lastReading.toStringAsFixed(0)} km',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colors.textDim),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: OdoField(
                    label: 'Start',
                    controller: _odoStartController,
                    error: _startTooLow,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppTheme.space14,
                    left: AppTheme.space8,
                    right: AppTheme.space8,
                  ),
                  child: Icon(Icons.arrow_forward, color: colors.textDimmer),
                ),
                Expanded(
                  child: OdoField(
                    label: 'End',
                    controller: _odoEndController,
                    error: _endTooLow,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_startTooLow) ...[
              const SizedBox(height: AppTheme.space10),
              ValidationMessage(
                isDanger: true,
                message: 'Start can\'t be below the last reading '
                    '(${lastReading!.toStringAsFixed(0)} km). The odometer '
                    'never runs backwards.',
              ),
            ],
            if (_endTooLow) ...[
              const SizedBox(height: AppTheme.space10),
              const ValidationMessage(
                isDanger: true,
                message: 'End reading must be greater than the start reading.',
              ),
            ],
            if (_odometerEntered) ...[
              const SizedBox(height: AppTheme.space16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space14,
                ),
                decoration: BoxDecoration(
                  color: _valid ? colors.accentTint : colors.surfaceInset,
                  border: Border.all(color: _valid ? colors.accent : colors.border),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'DISTANCE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _valid ? colors.accent : colors.textDimmer,
                            letterSpacing: 1.2,
                          ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: _odoKm.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: _valid ? colors.accent : colors.textDim,
                            ),
                        children: [
                          TextSpan(
                            text: ' km',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: _valid ? colors.accent : colors.textDim,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_mismatch) ...[
                const SizedBox(height: AppTheme.space10),
                ValidationMessage(
                  isDanger: false,
                  message: 'Entered distance (${_odoKm.toStringAsFixed(1)} km) '
                      'differs from the GPS-measured '
                      '${widget.gpsDistanceKm.toStringAsFixed(1)} km. '
                      'Double-check the readings.',
                ),
              ],
            ],
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
                    onPressed: _valid ? _save : null,
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
