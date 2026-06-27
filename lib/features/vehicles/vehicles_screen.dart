import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import 'providers/vehicles_list_provider.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Vehicle vehicle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Delete "${vehicle.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(vehiclesListProvider.notifier).deleteVehicle(vehicle.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.vehicleNew),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (list) {
            final colors = AppColors.of(context);
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_outlined,
                      size: 48,
                      color: colors.textGhost,
                    ),
                    const SizedBox(height: AppTheme.space14),
                    Text(
                      'No Vehicles Yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Tap + to add your first vehicle',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colors.textDim),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                AppTheme.space16,
                AppTheme.space16,
                AppTheme.space16,
                AppTheme.space16 + MediaQuery.of(context).padding.bottom + 72,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final vehicle = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space10),
                  child: _VehicleCard(
                    vehicle: vehicle,
                    onTap: () =>
                        context.push(AppRoutes.vehicleEditPath(vehicle.id)),
                    onDelete: () => _confirmDelete(context, ref, vehicle),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accentTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_car, color: colors.accent),
              ),
              const SizedBox(width: AppTheme.space14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vehicle.isDefault) ...[
                          const SizedBox(width: AppTheme.space8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.space8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: colors.accent),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      vehicle.plateNumber,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDim),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Row(
                      children: [
                        Icon(Icons.speed_outlined, size: 13, color: colors.textDimmer),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          '${NumberFormat('#,##0').format(vehicle.lastOdometer)} km',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textDimmer),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.speed_outlined),
                tooltip: 'Odometer log',
                onPressed: () => context
                    .push(AppRoutes.vehicleOdometerLogPath(vehicle.id)),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
