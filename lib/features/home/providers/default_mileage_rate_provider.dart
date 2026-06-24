import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/mileage_rate_service.dart';

/// The global default mileage rate (€/km), used by [Settings v2]'s rate
/// editor and as the fallback when a trip's vehicle has no rate of its own.
class DefaultMileageRateNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() => MileageRateService.getRate();

  Future<void> setRate(double rate) async {
    await MileageRateService.setRate(rate);
    state = AsyncData(rate);
  }
}

final defaultMileageRateProvider =
    AsyncNotifierProvider<DefaultMileageRateNotifier, double>(
  DefaultMileageRateNotifier.new,
);
