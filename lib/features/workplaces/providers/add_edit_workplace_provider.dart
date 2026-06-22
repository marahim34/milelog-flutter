import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';

/// ViewModel for [AddEditWorkplaceScreen]. The family argument is the
/// workplace id being edited, or null when adding a new one. UI never talks
/// to WorkplaceRepository or WorkPlacesDao directly (see CLAUDE.md MVVM rule).
class AddEditWorkplaceNotifier
    extends AutoDisposeFamilyAsyncNotifier<WorkPlace?, int?> {
  @override
  Future<WorkPlace?> build(int? workplaceId) async {
    if (workplaceId == null) return null;
    final repository = ref.watch(workplaceRepositoryProvider);
    return repository.getById(workplaceId);
  }

  Future<void> save({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool isHome,
  }) async {
    final repository = ref.read(workplaceRepositoryProvider);
    final existing = state.value;

    if (existing == null) {
      await repository.addWorkplace(
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        isHome: isHome,
      );
    } else {
      await repository.updateWorkplaceDetails(
        existing: existing,
        name: name,
        address: address,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        isHome: isHome,
      );
    }
  }
}

final addEditWorkplaceProvider = AsyncNotifierProvider.autoDispose
    .family<AddEditWorkplaceNotifier, WorkPlace?, int?>(
  AddEditWorkplaceNotifier.new,
);
