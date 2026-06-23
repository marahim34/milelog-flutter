import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../data/services/session_service.dart';

final highAccuracyGPSProvider = StateProvider<bool>((ref) => true);
final idleDetectionProvider = StateProvider<bool>((ref) => true);

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});

  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  void _handleVehiclesNavigation() {
    context.push(AppRoutes.vehicles);
  }

  void _handleWorkplacesNavigation() {
    context.push(AppRoutes.workplaces);
  }

  void _handleExportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting data...')),
    );
  }

  void _handleBackupData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating backup...')),
    );
  }

  void _handleRestoreData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restoring data...')),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final highAccuracyGPS = ref.watch(highAccuracyGPSProvider);
    final idleDetection = ref.watch(idleDetectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile section
              _SectionHeader(
                icon: Icons.person,
                title: 'Profile',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withAlpha(30),
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'John Doe',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'marahim34@gmail.com',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Preferences section
              _SectionHeader(
                icon: Icons.tune,
                title: 'Preferences',
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _ToggleSetting(
                      title: 'High Accuracy GPS',
                      subtitle: 'Use more battery for better location accuracy',
                      icon: Icons.gps_fixed,
                      value: highAccuracyGPS,
                      onChanged: (value) {
                        ref.read(highAccuracyGPSProvider.notifier).state =
                            value;
                      },
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    _ToggleSetting(
                      title: 'Idle Detection',
                      subtitle: 'Automatically pause trip when vehicle is idle',
                      icon: Icons.pause_circle,
                      value: idleDetection,
                      onChanged: (value) {
                        ref.read(idleDetectionProvider.notifier).state = value;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Management section
              _SectionHeader(
                icon: Icons.dashboard,
                title: 'Management',
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _NavigationTile(
                      title: 'Vehicles',
                      subtitle: 'Manage your vehicles',
                      icon: Icons.directions_car,
                      onTap: _handleVehiclesNavigation,
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    _NavigationTile(
                      title: 'Workplaces',
                      subtitle: 'Set up workplace locations',
                      icon: Icons.business,
                      onTap: _handleWorkplacesNavigation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Export & Backup section
              _SectionHeader(
                icon: Icons.cloud_upload,
                title: 'Export & Backup',
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _ActionTile(
                      title: 'Export Data',
                      subtitle: 'Export all trip data as JSON',
                      icon: Icons.file_download,
                      onTap: _handleExportData,
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    _ActionTile(
                      title: 'Backup Data',
                      subtitle: 'Create a backup of your data',
                      icon: Icons.backup,
                      onTap: _handleBackupData,
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor,
                    ),
                    _ActionTile(
                      title: 'Restore Data',
                      subtitle: 'Restore from a previous backup',
                      icon: Icons.restore,
                      onTap: _handleRestoreData,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Sign out button
              OutlinedButton.icon(
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // App version
              Center(
                child: Text(
                  'MileLog v2.0.0',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _ToggleSetting extends StatelessWidget {
  const _ToggleSetting({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.tertiary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
