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
  final _notesController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _companyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initFromTrip(Trip trip) {
    if (_initialized) return;
    _initialized = true;
    _tripType = TripType.fromString(trip.tripType);
    _companyController.text = trip.companyName;
    _notesController.text = trip.notes;
  }

  Future<void> _save() async {
    await ref.read(tripDetailProvider(widget.tripId).notifier).updateTripDetails(
          tripType: _tripType,
          companyName: _companyController.text.trim(),
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
                    Icon(Icons.info_outline, size: 14, color: colors.textDim),
                    const SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Text(
                        'Odometer is calculated automatically from your '
                        'vehicle settings.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textDim, height: 1.3),
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
                    onPressed: _save,
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
