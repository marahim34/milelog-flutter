import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import 'providers/odometer_log_provider.dart';

class OdometerLogScreen extends ConsumerWidget {
  const OdometerLogScreen({required this.vehicleId, super.key});

  final int vehicleId;

  Future<void> _handleAddReading(BuildContext context, WidgetRef ref) async {
    final value = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => const _AddReadingSheet(),
    );
    if (value != null) {
      await ref.read(odometerLogProvider(vehicleId).notifier).addReading(value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(odometerLogProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Odometer Log')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddReading(context, ref),
        child: const Icon(Icons.add),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (data) => _OdometerLogBody(state: data),
      ),
    );
  }
}

class _OdometerLogBody extends StatelessWidget {
  const _OdometerLogBody({required this.state});

  final OdometerLogState state;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final vehicle = state.vehicle;
    final readings = state.readings;
    final maxDelta = readings.length < 2
        ? 1.0
        : List.generate(readings.length - 1,
                (i) => readings[i].readingKm - readings[i + 1].readingKm)
            .fold<double>(1.0, (max, d) => d > max ? d : max);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppTheme.space24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space20,
            AppTheme.space14,
            AppTheme.space20,
            AppTheme.space10,
          ),
          child: Text(
            '${vehicle.name.toUpperCase()} · ${vehicle.plateNumber}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textDimmer),
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppTheme.space16),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT READING',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colors.textDimmer),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        vehicle.lastOdometer.toStringAsFixed(0),
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(width: AppTheme.space8),
                      Text(
                        'km',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: colors.textDim),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.space14),
        if (readings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space20),
                child: Text(
                  'No manual readings logged yet. Tap + to record one.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colors.textDim),
                ),
              ),
            ),
          )
        else
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppTheme.space16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < readings.length; i++)
                    _ReadingRow(
                      reading: readings[i],
                      delta: i < readings.length - 1
                          ? readings[i].readingKm - readings[i + 1].readingKm
                          : null,
                      maxDelta: maxDelta,
                      isLast: i == readings.length - 1,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({
    required this.reading,
    required this.delta,
    required this.maxDelta,
    required this.isLast,
  });

  final OdometerReading reading;
  final double? delta;
  final double maxDelta;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final date = DateTime.fromMillisecondsSinceEpoch(reading.timestamp);
    final fraction = delta == null ? 0.0 : (delta! / maxDelta).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space18,
        vertical: AppTheme.space10,
      ),
      decoration: isLast
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              DateFormat('MMM d').format(date).toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.textDim),
            ),
          ),
          const SizedBox(width: AppTheme.space10),
          Expanded(
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: colors.surfaceInset,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  FractionallySizedBox(
                    widthFactor: fraction == 0 ? 0.02 : fraction,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  if (delta != null)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppTheme.space8),
                      child: Text(
                        '+${delta!.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colors.accentInk,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space10),
          SizedBox(
            width: 64,
            child: Text(
              reading.readingKm.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddReadingSheet extends StatefulWidget {
  const _AddReadingSheet();

  @override
  State<_AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends State<_AddReadingSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log odometer reading',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.space18),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Reading (km)',
              prefixIcon: Icon(Icons.speed),
            ),
          ),
          const SizedBox(height: AppTheme.space18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTheme.space14),
                    side: BorderSide(color: colors.border),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppTheme.space10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
