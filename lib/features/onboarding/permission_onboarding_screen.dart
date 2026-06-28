import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/permission_onboarding_service.dart';

/// First-launch-only flow shown before login (see [AppRouter]'s redirect):
///
/// Step 0 — Location (required) + background location on Android 10+
/// Step 1 — Background activity / battery optimisation (required on Android)
/// Step 2 — Bluetooth (optional)
///
/// Each step shows its own "why" before the OS dialog fires, since asking
/// cold with no context is what gets permissions denied.
class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  int _step = 0;
  bool _isRequesting = false;

  static const _totalSteps = 3;

  Future<void> _handleLocationContinue() async {
    setState(() => _isRequesting = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      // Android 10+: background location ("Allow all the time") requires its
      // own OS dialog after foreground is granted. Without it the static
      // BluetoothAutoStartReceiver cannot start GPS when the app is killed.
      if (Platform.isAndroid &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        await Permission.locationAlways.request();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _step = 1;
        });
      }
    }
  }

  Future<void> _handleBatteryAllow() async {
    setState(() => _isRequesting = true);
    try {
      if (Platform.isAndroid) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _step = 2;
        });
      }
    }
  }

  Future<void> _handleBluetoothEnable() async {
    setState(() => _isRequesting = true);
    try {
      await Permission.bluetoothConnect.request();
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
    await _finish();
  }

  Future<void> _finish() async {
    await PermissionOnboardingService.setCompleted(true);
    AppRouter.session.onboardingCompleted = true;
    if (!mounted) return;
    context.go(AppRouter.session.isLoggedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space24),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.space20),
              Row(
                children: [
                  for (var i = 0; i < _totalSteps; i++) ...[
                    if (i > 0) const SizedBox(width: AppTheme.space8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _step ? colors.accent : colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              if (_step == 0)
                _PermissionStep(
                  key: const ValueKey('location-step'),
                  icon: Icons.my_location,
                  title: 'Location access',
                  body: 'MileLog uses your location to automatically track '
                      'trip distance and routes, and to detect when you '
                      'arrive at a saved workplace. This is required for '
                      'the app to work.',
                  primaryLabel: 'Continue',
                  isBusy: _isRequesting,
                  onPrimary: _handleLocationContinue,
                  footnote: 'You can review this anytime in '
                      'Settings → Permissions.',
                )
              else if (_step == 1)
                _PermissionStep(
                  key: const ValueKey('battery-step'),
                  icon: Icons.battery_charging_full,
                  title: 'Background activity',
                  body: 'GPS tracking must keep running when your screen '
                      'is off or you switch to another app. Without this, '
                      'your phone may pause tracking mid-trip and miss '
                      'distance. Tap Allow on the next screen to keep '
                      'MileLog always active.',
                  primaryLabel: 'Allow',
                  isBusy: _isRequesting,
                  onPrimary: _handleBatteryAllow,
                  secondaryLabel: 'Skip',
                  onSecondary: () => setState(() => _step = 2),
                  footnote: 'This only prevents the OS from sleeping the app — '
                      'it does not drain your battery faster.',
                )
              else
                _PermissionStep(
                  key: const ValueKey('bluetooth-step'),
                  icon: Icons.bluetooth,
                  title: 'Bluetooth access',
                  subtitle: 'Optional',
                  body: 'Pair your vehicle\'s Bluetooth to automatically '
                      'start tracking when you connect, and pause when you '
                      'disconnect. Not everyone uses this — skip it if you '
                      'prefer to start trips manually.',
                  primaryLabel: 'Enable',
                  isBusy: _isRequesting,
                  onPrimary: _handleBluetoothEnable,
                  secondaryLabel: 'Skip',
                  onSecondary: _finish,
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.isBusy,
    this.secondaryLabel,
    this.onSecondary,
    this.footnote,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool isBusy;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: colors.accentTint,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32, color: colors.accent),
        ),
        const SizedBox(height: AppTheme.space24),
        if (subtitle != null) ...[
          Text(
            subtitle!.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: colors.accent, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppTheme.space8),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppTheme.space14),
        Text(
          body,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: colors.textDim, height: 1.4),
        ),
        const SizedBox(height: AppTheme.space24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBusy ? null : onPrimary,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
              child: isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(primaryLabel),
            ),
          ),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: AppTheme.space10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: isBusy ? null : onSecondary,
              child: Text(secondaryLabel!),
            ),
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: AppTheme.space16),
          Text(
            footnote!,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colors.textDimmer),
          ),
        ],
      ],
    );
  }
}
