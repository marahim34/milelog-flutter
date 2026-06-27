import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/services/bluetooth_service.dart';
import '../../../data/services/session_service.dart';
import '../../vehicles/providers/vehicles_list_provider.dart';
import '../../workplaces/providers/workplaces_list_provider.dart';
import '../providers/bluetooth_auto_tracking_enabled_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/default_mileage_rate_provider.dart';
import '../providers/profile_provider.dart';

final highAccuracyGPSProvider = StateProvider<bool>((ref) => true);
final idleDetectionProvider = StateProvider<bool>((ref) => true);

final _packageInfoProvider =
    FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

final _locationPermissionProvider =
    FutureProvider.autoDispose<LocationPermission>(
  (ref) => Geolocator.checkPermission(),
);

final _bluetoothPermissionProvider = FutureProvider.autoDispose<bool>(
  (ref) => BluetoothService.hasPermission(),
);

/// The vehicle the odometer section corrects — the one marked default, or
/// just the first vehicle when none is, so the section still has something
/// to show for a single-vehicle household that never bothered to flip it.
Vehicle? _defaultVehicleFrom(List<Vehicle> list) {
  if (list.isEmpty) return null;
  for (final vehicle in list) {
    if (vehicle.isDefault) return vehicle;
  }
  return list.first;
}

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await SessionService.setLoggedIn(false);
              AppRouter.session.isLoggedIn = false;
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenLocationSettings() async {
    await Geolocator.openAppSettings();
    ref.invalidate(_locationPermissionProvider);
  }

  Future<void> _handleBluetoothPermission() async {
    final status = await Permission.bluetoothConnect.status;
    if (status.isGranted || status.isPermanentlyDenied) {
      // Android never lets an app revoke its own permission grant — hand
      // off to the system App Info screen so the user can turn it off
      // themselves (see Settings → Permissions → Bluetooth access).
      await openAppSettings();
    } else {
      await Permission.bluetoothConnect.request();
    }
    ref.invalidate(_bluetoothPermissionProvider);
  }

  Future<void> _handleEditOdometer(Vehicle vehicle) async {
    final saved = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => _OdometerEditorSheet(
        vehicleName: vehicle.name,
        initialReading: vehicle.lastOdometer,
      ),
    );
    if (saved == null) return;
    await ref
        .read(vehicleRepositoryProvider)
        .setOdometerReading(vehicle.id, saved);
  }

  Future<void> _handleEditRate() async {
    final current = await ref.read(defaultMileageRateProvider.future);
    if (!mounted) return;
    final saved = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => _RateEditorSheet(initialRate: current),
    );
    if (saved != null) {
      await ref.read(defaultMileageRateProvider.notifier).setRate(saved);
    }
  }

  Future<void> _handleEditCurrency() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => const _CurrencySheet(),
    );
  }

  Future<void> _handleEditProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      isScrollControlled: true,
      builder: (context) => const _ProfileSheet(),
    );
  }

  Future<void> _handleEditTheme() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => const _ThemeModeSheet(),
    );
  }

  Future<void> _handleEditPalette() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.cardRadius)),
      ),
      builder: (context) => const _PaletteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final highAccuracyGPS = ref.watch(highAccuracyGPSProvider);
    final idleDetection = ref.watch(idleDetectionProvider);
    final rate = ref.watch(defaultMileageRateProvider);
    final currency = ref.watch(currencyCodeProvider);
    final vehicles = ref.watch(vehiclesListProvider);
    final workplaces = ref.watch(workplacesListProvider);
    final packageInfo = ref.watch(_packageInfoProvider);
    final locationPermission = ref.watch(_locationPermissionProvider);
    final bluetoothPermission = ref.watch(_bluetoothPermissionProvider);
    final bluetoothAutoTracking =
        ref.watch(bluetoothAutoTrackingEnabledProvider);
    final themeMode = ref.watch(themeModeProvider);
    final palette = ref.watch(paletteProvider);
    final profile = ref.watch(profileProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.only(
            bottom: AppTheme.space24 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            _Header(packageInfo: packageInfo),
            if (bluetoothPermission.value == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.space16,
                  0,
                  AppTheme.space16,
                  AppTheme.space8,
                ),
                child: _PermissionBanner(
                  onReview: _handleBluetoothPermission,
                ),
              ),
            const _SectionLabel(title: 'PREFERENCES'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: _SettingsCard(
                children: [
                  _ToggleRow(
                    icon: Icons.gps_fixed,
                    title: 'High Accuracy GPS',
                    subtitle: 'Use more battery for better location accuracy',
                    value: highAccuracyGPS,
                    onChanged: (value) => ref
                        .read(highAccuracyGPSProvider.notifier)
                        .state = value,
                  ),
                  _ToggleRow(
                    icon: Icons.pause_circle_outline,
                    title: 'Idle Detection',
                    subtitle: 'Automatically pause trip when vehicle is idle',
                    value: idleDetection,
                    onChanged: (value) =>
                        ref.read(idleDetectionProvider.notifier).state = value,
                  ),
                  _ToggleRow(
                    icon: Icons.bluetooth,
                    title: 'Bluetooth Auto-Tracking',
                    subtitle: 'Start/pause trips when a paired vehicle '
                        'connects or disconnects',
                    value: bluetoothAutoTracking.value ?? true,
                    onChanged: (value) => ref
                        .read(bluetoothAutoTrackingEnabledProvider.notifier)
                        .setEnabled(value),
                  ),
                  _SettingRow(
                    icon: Icons.payments_outlined,
                    title: 'Mileage rate',
                    subtitle: 'Default rate used when a vehicle has none set',
                    onTap: _handleEditRate,
                    trailing: Text(
                      rate.when(
                        data: (value) =>
                            '${value.toStringAsFixed(2)} $currency',
                        loading: () => '—',
                        error: (_, __) => '—',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.currency_exchange,
                    title: 'Currency',
                    subtitle: 'Used in reports and cost calculations',
                    onTap: _handleEditCurrency,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currency,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colors.textDim),
                        ),
                        Icon(Icons.chevron_right, color: colors.textDimmer),
                      ],
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.dark_mode_outlined,
                    title: 'Theme',
                    subtitle: switch (themeMode) {
                      ThemeMode.light => 'Light mode',
                      ThemeMode.dark => 'Dark mode',
                      ThemeMode.system => 'Follows system',
                    },
                    onTap: _handleEditTheme,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          switch (themeMode) {
                            ThemeMode.light => 'Light',
                            ThemeMode.dark => 'Dark',
                            ThemeMode.system => 'System',
                          },
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colors.textDim),
                        ),
                        Icon(Icons.chevron_right, color: colors.textDimmer),
                      ],
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.palette_outlined,
                    title: 'Palette',
                    subtitle: 'Accent color theme',
                    isLast: true,
                    onTap: _handleEditPalette,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(
                              right: AppTheme.space8),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          switch (palette) {
                            AppPalette.rose => 'Rose',
                            AppPalette.lime => 'Lime',
                            AppPalette.cyan => 'Cyan',
                          },
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colors.textDim),
                        ),
                        Icon(Icons.chevron_right, color: colors.textDimmer),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _SectionLabel(title: 'MANAGEMENT'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: _SettingsCard(
                children: [
                  _SettingRow(
                    icon: Icons.directions_car_outlined,
                    title: 'Vehicles',
                    subtitle: vehicles.when(
                      data: (list) {
                        if (list.isEmpty) return 'No vehicles added';
                        Vehicle? defaultVehicle;
                        for (final vehicle in list) {
                          if (vehicle.isDefault) {
                            defaultVehicle = vehicle;
                            break;
                          }
                        }
                        final count =
                            '${list.length} vehicle${list.length == 1 ? '' : 's'}';
                        return defaultVehicle == null
                            ? count
                            : '$count · ${defaultVehicle.name} (default)';
                      },
                      loading: () => 'Loading…',
                      error: (_, __) => 'Unavailable',
                    ),
                    trailing:
                        Icon(Icons.chevron_right, color: colors.textDimmer),
                    onTap: () => context.push(AppRoutes.vehicles),
                  ),
                  _SettingRow(
                    icon: Icons.location_on_outlined,
                    title: 'Workplaces',
                    subtitle: workplaces.when(
                      data: (list) =>
                          '${list.length} location${list.length == 1 ? '' : 's'}',
                      loading: () => 'Loading…',
                      error: (_, __) => 'Unavailable',
                    ),
                    trailing:
                        Icon(Icons.chevron_right, color: colors.textDimmer),
                    onTap: () => context.push(AppRoutes.workplaces),
                    isLast: true,
                  ),
                ],
              ),
            ),
            const _SectionLabel(title: 'ODOMETER'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: _SettingsCard(
                children: [
                  vehicles.when(
                    data: (list) {
                      final vehicle = _defaultVehicleFrom(list);
                      if (vehicle == null) {
                        return const _SettingRow(
                          icon: Icons.speed_outlined,
                          title: 'No vehicle set',
                          subtitle: 'Add a vehicle first to track its odometer',
                          isLast: true,
                        );
                      }
                      return _SettingRow(
                        icon: Icons.speed_outlined,
                        title: vehicle.name,
                        subtitle:
                            '${NumberFormat('#,##0').format(vehicle.lastOdometer)} km '
                            '· Tap to correct',
                        trailing:
                            Icon(Icons.chevron_right, color: colors.textDimmer),
                        onTap: () => _handleEditOdometer(vehicle),
                        isLast: true,
                      );
                    },
                    loading: () => const _SettingRow(
                      icon: Icons.speed_outlined,
                      title: 'Odometer',
                      subtitle: 'Loading…',
                      isLast: true,
                    ),
                    error: (_, __) => const _SettingRow(
                      icon: Icons.speed_outlined,
                      title: 'Odometer',
                      subtitle: 'Unavailable',
                      isLast: true,
                    ),
                  ),
                ],
              ),
            ),
            const _SectionLabel(title: 'PERMISSIONS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: _SettingsCard(
                children: [
                  _SettingRow(
                    icon: Icons.my_location,
                    title: 'Location access',
                    subtitle: 'Required for trip tracking',
                    onTap: locationPermission.maybeWhen(
                      data: (p) => p == LocationPermission.always ||
                              p == LocationPermission.whileInUse
                          ? null
                          : _handleOpenLocationSettings,
                      orElse: () => null,
                    ),
                    trailing: locationPermission.when(
                      data: (p) => _StatusChip(
                        label: switch (p) {
                          LocationPermission.always => 'Always',
                          LocationPermission.whileInUse => 'In use',
                          LocationPermission.denied => 'Denied',
                          LocationPermission.deniedForever => 'Denied',
                          LocationPermission.unableToDetermine => 'Unknown',
                        },
                        tone: (p == LocationPermission.always ||
                                p == LocationPermission.whileInUse)
                            ? _ChipTone.success
                            : _ChipTone.warning,
                      ),
                      loading: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const _StatusChip(
                          label: 'Unknown', tone: _ChipTone.warning),
                    ),
                  ),
                  _SettingRow(
                    icon: Icons.bluetooth,
                    title: 'Bluetooth access',
                    subtitle: bluetoothPermission.maybeWhen(
                      data: (granted) => granted
                          ? 'Tap to manage in system settings'
                          : 'Needed for vehicle auto-start tracking',
                      orElse: () => 'Needed for vehicle auto-start tracking',
                    ),
                    isLast: true,
                    onTap: _handleBluetoothPermission,
                    trailing: bluetoothPermission.when(
                      data: (granted) => _StatusChip(
                        label: granted ? 'Granted' : 'Needs review',
                        tone: granted ? _ChipTone.success : _ChipTone.warning,
                      ),
                      loading: () => const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const _StatusChip(
                          label: 'Unknown', tone: _ChipTone.warning),
                    ),
                  ),
                ],
              ),
            ),
            const _SectionLabel(title: 'PROFILE'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: _SettingsCard(
                children: [
                  _SettingRow(
                    icon: Icons.business_outlined,
                    title: 'Company / Name',
                    subtitle: profile.name.isEmpty
                        ? 'Appears on PDF report cover'
                        : profile.name,
                    trailing:
                        Icon(Icons.chevron_right, color: colors.textDimmer),
                    onTap: _handleEditProfile,
                    isLast: true,
                  ),
                ],
              ),
            ),
            const _SectionLabel(title: 'ACCOUNT'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space16),
              child: _SettingsCard(
                children: [
                  _SettingRow(
                    icon: Icons.logout,
                    title: 'Sign out',
                    danger: true,
                    isLast: true,
                    onTap: _handleSignOut,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.space24),
              child: Center(
                child: Text(
                  packageInfo.when(
                    data: (info) =>
                        'MILELOG · v${info.version} · BUILD ${info.buildNumber}',
                    loading: () => 'MILELOG',
                    error: (_, __) => 'MILELOG',
                  ),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.packageInfo});

  final AsyncValue<PackageInfo> packageInfo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space14,
        AppTheme.space20,
        AppTheme.space10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            packageInfo.when(
              data: (info) => 'MILELOG / v${info.version}',
              loading: () => 'MILELOG',
              error: (_, __) => 'MILELOG',
            ),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: AppTheme.space4),
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space8,
      ),
      child: Text(title, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = danger ? colors.danger : colors.accent;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints:
            const BoxConstraints(minHeight: AppTheme.settingsRowMinHeight),
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: danger
                    ? colors.danger.withValues(alpha: 0.14)
                    : colors.accentTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppTheme.space14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: danger ? colors.danger : colors.textPrimary,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppTheme.space4),
                    Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textDim),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppTheme.space10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}

enum _ChipTone { success, warning, danger }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = switch (tone) {
      _ChipTone.success => colors.success,
      _ChipTone.warning => colors.warning,
      _ChipTone.danger => colors.danger,
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.space8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onReview});

  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space14),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.08),
        border: Border.all(color: colors.warning),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.bluetooth, color: colors.warning, size: 18),
          ),
          const SizedBox(width: AppTheme.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bluetooth permission needed',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Required to auto-start tracking when a paired vehicle connects',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space10),
          ElevatedButton(
            onPressed: onReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.warning,
              foregroundColor: colors.accentInk,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space10,
                vertical: AppTheme.space8,
              ),
            ),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

class _OdometerEditorSheet extends StatefulWidget {
  const _OdometerEditorSheet({
    required this.vehicleName,
    required this.initialReading,
  });

  final String vehicleName;
  final double initialReading;

  @override
  State<_OdometerEditorSheet> createState() => _OdometerEditorSheetState();
}

class _OdometerEditorSheetState extends State<_OdometerEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialReading.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
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
          Text('Correct odometer',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.space4),
          Text(
            widget.vehicleName,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: colors.textDim),
          ),
          const SizedBox(height: AppTheme.space18),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.space20,
              horizontal: AppTheme.space16,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceInset,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 170,
                  child: TextField(
                    controller: _controller,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: colors.accent,
                        ),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space8),
                Text('km',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: colors.textDim)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space18),
          Text(
            "Corrects this vehicle's current reading. Past trips are kept "
            'exactly as recorded — only the starting point of the odometer '
            'chain shifts to match.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.textDim),
          ),
          const SizedBox(height: AppTheme.space20),
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

class _RateEditorSheet extends ConsumerStatefulWidget {
  const _RateEditorSheet({required this.initialRate});

  final double initialRate;

  @override
  ConsumerState<_RateEditorSheet> createState() => _RateEditorSheetState();
}

class _RateEditorSheetState extends ConsumerState<_RateEditorSheet> {
  late final TextEditingController _controller;

  static const _presets = ['0.45', '0.50', '0.55', '0.60'];

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.initialRate.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (value == null || value <= 0) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currency = ref.watch(currencyCodeProvider);
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
          Text('Mileage rate', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTheme.space18),
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.space20,
              horizontal: AppTheme.space16,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceInset,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    SizedBox(
                      width: 170,
                      child: TextField(
                        controller: _controller,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(color: colors.accent),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.space4),
                Text('$currency / KM',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: colors.textDim)),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space18),
          Wrap(
            spacing: AppTheme.space8,
            runSpacing: AppTheme.space8,
            children: [
              for (final preset in _presets)
                _RatePresetChip(
                  label: preset,
                  selected: _controller.text == preset,
                  onTap: () => setState(() => _controller.text = preset),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space18),
          Text(
            'Used when a vehicle has no rate of its own set in its profile. '
            'Applies to business trips only — personal trips are never '
            'reimbursed.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.textDim),
          ),
          const SizedBox(height: AppTheme.space20),
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

class _RatePresetChip extends StatelessWidget {
  const _RatePresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space14,
          vertical: AppTheme.space10,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.accentTint : colors.surfaceInset,
          border: Border.all(color: selected ? colors.accent : colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? colors.accent : colors.textDim,
              ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space10,
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isLast = false,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space20,
          vertical: AppTheme.space14,
        ),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.border)),
              ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: AppTheme.space10),
            ],
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? colors.accent : colors.textDimmer,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeModeSheet extends ConsumerWidget {
  const _ThemeModeSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetTitle(title: 'Theme'),
          _RadioRow(
            label: 'Light',
            selected: themeMode == ThemeMode.light,
            onTap: () {
              setAppThemeMode(ref, ThemeMode.light);
              Navigator.of(context).pop();
            },
          ),
          _RadioRow(
            label: 'Dark',
            selected: themeMode == ThemeMode.dark,
            onTap: () {
              setAppThemeMode(ref, ThemeMode.dark);
              Navigator.of(context).pop();
            },
          ),
          _RadioRow(
            label: 'System default',
            selected: themeMode == ThemeMode.system,
            isLast: true,
            onTap: () {
              setAppThemeMode(ref, ThemeMode.system);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppTheme.space10),
        ],
      ),
    );
  }
}

class _PaletteSheet extends ConsumerWidget {
  const _PaletteSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final brightness = Theme.of(context).brightness;

    Widget swatch(AppPalette p) => Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppTheme.colorsFor(p, brightness).accent,
            shape: BoxShape.circle,
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetTitle(title: 'Palette'),
          _RadioRow(
            label: 'Rose',
            selected: palette == AppPalette.rose,
            trailing: swatch(AppPalette.rose),
            onTap: () {
              setAppPalette(ref, AppPalette.rose);
              Navigator.of(context).pop();
            },
          ),
          _RadioRow(
            label: 'Lime',
            selected: palette == AppPalette.lime,
            trailing: swatch(AppPalette.lime),
            onTap: () {
              setAppPalette(ref, AppPalette.lime);
              Navigator.of(context).pop();
            },
          ),
          _RadioRow(
            label: 'Cyan',
            selected: palette == AppPalette.cyan,
            trailing: swatch(AppPalette.cyan),
            isLast: true,
            onTap: () {
              setAppPalette(ref, AppPalette.cyan);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: AppTheme.space10),
        ],
      ),
    );
  }
}

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _nameCtrl = TextEditingController(text: profile.name);
    _addressCtrl = TextEditingController(text: profile.address);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _emailCtrl = TextEditingController(text: profile.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(profileProvider.notifier).update(
          ProfileData(
            name: _nameCtrl.text.trim(),
            address: _addressCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20,
        AppTheme.space20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Used on the PDF report cover page',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.of(context).textDim),
            ),
            const SizedBox(height: AppTheme.space18),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Company / Full name',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppTheme.space14),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppTheme.space14),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppTheme.space14),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppTheme.space20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.space14),
                      side: BorderSide(
                          color: AppColors.of(context).border),
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
      ),
    );
  }
}

class _CurrencySheet extends ConsumerWidget {
  const _CurrencySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currencyCodeProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetTitle(title: 'Currency'),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: supportedCurrencies.length,
              itemBuilder: (context, i) => _RadioRow(
                label: '${supportedCurrencies[i].$1}  —  '
                    '${supportedCurrencies[i].$2}',
                selected: current == supportedCurrencies[i].$1,
                isLast: i == supportedCurrencies.length - 1,
                onTap: () {
                  ref
                      .read(currencyCodeProvider.notifier)
                      .setCurrency(supportedCurrencies[i].$1);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
          SizedBox(
            height:
                AppTheme.space10 + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }
}
