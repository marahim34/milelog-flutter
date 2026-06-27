import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/trip_type.dart';
import 'providers/trip_detail_provider.dart';
import 'widgets/trip_widgets.dart';

/// The editable "Edit trip" form — pushed from [TripDetailScreen]'s sticky
/// "Edit trip" button, never shown as a modal sheet. Matches the bundled
/// `EditTrip` component (decoded from design_handoff_milelog/prototype/
/// MileLog Trip Details.html): the GPS route stays locked/read-only on the
/// previous screen, only classification (type/odometer/company/notes) is
/// editable here. Saving writes through [TripDetailNotifier] and pops back
/// to Trip details; Cancel/back discards without writing.
class EditTripScreen extends ConsumerStatefulWidget {
  const EditTripScreen({required this.tripId, super.key});

  final int tripId;

  @override
  ConsumerState<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends ConsumerState<EditTripScreen> {
  TripType _tripType = TripType.business;
  final _companyController = TextEditingController();
  final _odoStartController = TextEditingController();
  final _odoEndController = TextEditingController();
  final _notesController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _companyController.dispose();
    _odoStartController.dispose();
    _odoEndController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initFromTrip(Trip trip) {
    if (_initialized) return;
    _initialized = true;
    _tripType = TripType.fromString(trip.tripType);
    _companyController.text = trip.companyName;
    _odoStartController.text =
        trip.odometerStart > 0 ? trip.odometerStart.toStringAsFixed(0) : '';
    _odoEndController.text =
        trip.odometerEnd > 0 ? trip.odometerEnd.toStringAsFixed(0) : '';
    _notesController.text = trip.notes;
  }

  double get _odoStart => double.tryParse(_odoStartController.text.trim()) ?? 0;
  double get _odoEnd => double.tryParse(_odoEndController.text.trim()) ?? 0;
  double get _odoKm => (_odoEnd - _odoStart).clamp(0, double.infinity);

  // Unlike the just-stopped "Ended Trip" flow, there's no valid lower bound
  // to guard the start reading against here: the vehicle's *current*
  // odometer has advanced past every trip since this one, so it can't be
  // used as "the last reading before this trip" without summing the trips
  // in between. Only the start<=end ordering and the GPS cross-check apply.
  bool get _endTooLow => _odoStart > 0 && _odoEnd > 0 && _odoEnd < _odoStart;
  bool get _valid => !_endTooLow;

  bool _mismatch(double gpsDistanceKm) =>
      _valid && _odoStart > 0 && _odoEnd > 0 && (_odoKm - gpsDistanceKm).abs() > 5;

  Future<void> _save() async {
    if (!_valid) return;
    await ref.read(tripDetailProvider(widget.tripId).notifier).updateTripDetails(
          tripType: _tripType,
          companyName: _companyController.text.trim(),
          odometerStart: _odoStart,
          odometerEnd: _odoEnd,
          notes: _notesController.text.trim(),
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final detailState = ref.watch(tripDetailProvider(widget.tripId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: const Text('Edit trip'),
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (detail) {
          _initFromTrip(detail.trip);
          final gpsDistanceKm = detail.trip.distanceKm;
          final mismatch = _mismatch(gpsDistanceKm);

          return ListView(
            padding: const EdgeInsets.all(AppTheme.space16),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space14,
                  vertical: AppTheme.space10,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceInset,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: colors.textDim),
                    const SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Text(
                        'The GPS route is locked. You can edit the '
                        'classification below.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textDim, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space18),
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
              Text(
                'ODOMETER',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.textDimmer, letterSpacing: 1.2),
              ),
              const SizedBox(height: AppTheme.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: OdoField(
                      label: 'Start',
                      controller: _odoStartController,
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
              if (_endTooLow) ...[
                const SizedBox(height: AppTheme.space10),
                const ValidationMessage(
                  isDanger: true,
                  message: 'End reading must be greater than the start reading.',
                ),
              ],
              if (_odoStart > 0 || _odoEnd > 0) ...[
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
                if (mismatch) ...[
                  const SizedBox(height: AppTheme.space10),
                  ValidationMessage(
                    isDanger: false,
                    message: 'Entered distance (${_odoKm.toStringAsFixed(1)} km) '
                        'differs from the GPS-measured '
                        '${gpsDistanceKm.toStringAsFixed(1)} km. '
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
            ],
          );
        },
      ),
      bottomNavigationBar: detailState.maybeWhen(
        data: (_) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.space14),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.space14),
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
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.space14),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }
}
