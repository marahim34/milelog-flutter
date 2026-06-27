import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tracking/providers/trip_recovery_provider.dart';
import '../tracking/widgets/trip_recovery_dialog.dart';
import 'tabs/drive_tab.dart';
import 'tabs/logs_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/settings_tab.dart';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // Check for interrupted trips on app launch (after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForTripRecovery();
    });
  }

  void _checkForTripRecovery() {
    final recoveryState = ref.read(tripRecoveryProvider);
    if (recoveryState is TripRecoveryNeedsRecovery) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => TripRecoveryDialog(
          tripId: recoveryState.tripId,
          startTimeMs: recoveryState.startTimeMs,
          distanceKm: recoveryState.distanceKm,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    ref.read(selectedTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedTabIndexProvider);

    // Single source of truth for which page is shown — keeps the bottom nav
    // and any other widget (e.g. a "See all" link) able to switch tabs by
    // just writing to the provider, not just direct taps.
    ref.listen(selectedTabIndexProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.jumpToPage(next);
      }
    });

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          ref.read(selectedTabIndexProvider.notifier).state = index;
        },
        children: const [
          DriveTab(),
          LogsTab(),
          ReportsTab(),
          SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'Drive',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Logs',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
