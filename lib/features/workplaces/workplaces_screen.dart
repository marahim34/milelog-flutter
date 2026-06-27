import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import 'providers/workplaces_list_provider.dart';

class WorkplacesScreen extends ConsumerWidget {
  const WorkplacesScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkPlace workplace,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Workplace'),
        content: Text('Delete "${workplace.name}"? This cannot be undone.'),
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
      await ref
          .read(workplacesListProvider.notifier)
          .deleteWorkplace(workplace.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final workplaces = ref.watch(workplacesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workplaces')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.workplaceNew),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: workplaces.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error: $error')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 48,
                      color: colors.textGhost,
                    ),
                    const SizedBox(height: AppTheme.space14),
                    Text(
                      'No Workplaces Yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      'Tap + to add your first workplace',
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
                final workplace = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space10),
                  child: _WorkplaceCard(
                    workplace: workplace,
                    onTap: () =>
                        context.push(AppRoutes.workplaceEditPath(workplace.id)),
                    onDelete: () => _confirmDelete(context, ref, workplace),
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

class _WorkplaceCard extends StatelessWidget {
  const _WorkplaceCard({
    required this.workplace,
    required this.onTap,
    required this.onDelete,
  });

  final WorkPlace workplace;
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
                child: Icon(
                  workplace.isHome ? Icons.home_outlined : Icons.business_outlined,
                  color: colors.accent,
                ),
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
                            workplace.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (workplace.isHome) ...[
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
                              'HOME',
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
                      workplace.address,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDim),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Row(
                      children: [
                        Icon(
                          Icons.my_location_outlined,
                          size: 13,
                          color: colors.textDimmer,
                        ),
                        const SizedBox(width: AppTheme.space4),
                        Text(
                          '${workplace.radiusMeters.toStringAsFixed(0)} m geofence',
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
