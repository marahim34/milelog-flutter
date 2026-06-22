import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';

/// ViewModel for [WorkplacesScreen]. UI never talks to WorkplaceRepository
/// or WorkPlacesDao directly (see CLAUDE.md MVVM rule).
class WorkplacesListNotifier extends StreamNotifier<List<WorkPlace>> {
  @override
  Stream<List<WorkPlace>> build() {
    final repository = ref.watch(workplaceRepositoryProvider);
    return repository.watchAll();
  }

  Future<void> deleteWorkplace(int id) async {
    final repository = ref.read(workplaceRepositoryProvider);
    await repository.deleteWorkplace(id);
  }
}

final workplacesListProvider =
    StreamNotifierProvider<WorkplacesListNotifier, List<WorkPlace>>(
  WorkplacesListNotifier.new,
);
