import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/state/location_controller.dart';
import '../../gallery/presentation/gallery_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'live_camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationController>();
    final snapshot = location.snapshot;
    final ready = location.hasCaptureAccuracy;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(
              title: ready ? 'GPS ready' : 'Improving GPS lock',
              subtitle: location.message ?? 'Starting GPS',
              icon: ready ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: ready ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            _AccuracyCard(
              accuracy: snapshot?.accuracy,
              latitude: snapshot?.latitude,
              longitude: snapshot?.longitude,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Capture Photo'),
              onPressed: ready
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LiveCameraScreen(),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const GalleryScreen())),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Settings'),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.14),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard({
    required this.accuracy,
    required this.latitude,
    required this.longitude,
  });

  final double? accuracy;
  final double? latitude;
  final double? longitude;

  @override
  Widget build(BuildContext context) {
    final accuracyText = accuracy == null
        ? '--'
        : '${accuracy!.toStringAsFixed(1)}m';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Accuracy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(accuracyText, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              latitude == null || longitude == null
                  ? 'Waiting for coordinates'
                  : 'Lat ${latitude!.toStringAsFixed(6)}  Long ${longitude!.toStringAsFixed(6)}',
            ),
          ],
        ),
      ),
    );
  }
}
