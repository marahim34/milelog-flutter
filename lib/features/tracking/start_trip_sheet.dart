import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../../data/models/trip_type.dart';
import '../vehicles/providers/vehicles_list_provider.dart';
import 'providers/tracking_screen_args.dart';

export 'providers/tracking_screen_args.dart';

/// Vehicle + trip-type picker shown from the docked FAB, matching
/// flows.jsx's `StartTripSheet`. Returns a [TrackingScreenArgs] via
/// `Navigator.pop`, or null if dismissed without starting.
class StartTripSheet extends ConsumerStatefulWidget {
  const StartTripSheet({super.key});

  @override
  ConsumerState<StartTripSheet> createState() => _StartTripSheetState();
}

class _StartTripSheetState extends ConsumerState<StartTripSheet> {
  TripType _tripType = TripType.business;
  int? _selectedVehicleId;
  bool _defaultApplied = false;

  Vehicle? _defaultVehicleOf(List<Vehicle> vehicles) {
    for (final vehicle in vehicles) {
      if (vehicle.isDefault) return vehicle;
    }
    return vehicles.isEmpty ? null : vehicles.first;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final vehicles = ref.watch(vehiclesListProvider).value ?? const <Vehicle>[];

    if (!_defaultApplied && vehicles.isNotEmpty) {
      _selectedVehicleId = _defaultVehicleOf(vehicles)?.id;
      _defaultApplied = true;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space20,
            AppTheme.space20,
            AppTheme.space20,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Start trip', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.space18),
              Row(
                children: [
                  Expanded(
                    child: _TypeButton(
                      icon: Icons.business_center_outlined,
                      label: 'Business',
                      selected: _tripType == TripType.business,
                      onTap: () =>
                          setState(() => _tripType = TripType.business),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space8),
                  Expanded(
                    child: _TypeButton(
                      icon: Icons.person_outline,
                      label: 'Personal',
                      selected: _tripType == TripType.personal,
                      onTap: () =>
                          setState(() => _tripType = TripType.personal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space18),
              Text(
                'VEHICLE',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colors.textDimmer),
              ),
              const SizedBox(height: AppTheme.space8),
              if (vehicles.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.space10),
                  child: Text(
                    'No vehicles added yet — you can still start without one.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textDim),
                  ),
                )
              else
                for (final vehicle in vehicles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space8),
                    child: _VehicleOption(
                      vehicle: vehicle,
                      selected: _selectedVehicleId == vehicle.id,
                      onTap: () =>
                          setState(() => _selectedVehicleId = vehicle.id),
                    ),
                  ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: AppTheme.space16,
            right: AppTheme.space16,
            top: AppTheme.space8,
            bottom: MediaQuery.of(context).padding.bottom + AppTheme.space16,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(
                TrackingScreenArgs(
                  vehicleId: _selectedVehicleId,
                  tripType: _tripType,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: AppTheme.space14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: AppTheme.space8),
                  Text('Start trip'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space14),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : colors.surfaceInset,
          border: Border.all(color: selected ? colors.accent : colors.border),
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? colors.accent : colors.textDim),
            const SizedBox(height: AppTheme.space4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? colors.accent : colors.textDim,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleOption extends StatelessWidget {
  const _VehicleOption({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space10),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : colors.surfaceInset,
          border: Border.all(color: selected ? colors.accent : colors.border),
          borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.directions_car,
                color: selected ? colors.accent : colors.textDim,
              ),
            ),
            const SizedBox(width: AppTheme.space10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vehicle.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                  ),
                  Text(
                    '${vehicle.plateNumber} · ${vehicle.lastOdometer.toStringAsFixed(0)} km',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textDim),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check, color: colors.accent),
          ],
        ),
      ),
    );
  }
}
