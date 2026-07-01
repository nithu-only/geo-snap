import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/state/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Watermark Template',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<WatermarkTemplate>(
            segments: const [
              ButtonSegment(
                value: WatermarkTemplate.compact,
                label: Text('Compact'),
              ),
              ButtonSegment(
                value: WatermarkTemplate.largePanel,
                label: Text('Large'),
              ),
              ButtonSegment(
                value: WatermarkTemplate.gpsMapCamera,
                label: Text('GPS'),
              ),
            ],
            selected: {settings.template},
            onSelectionChanged: (value) {
              controller.update(settings.copyWith(template: value.first));
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Watermark Position',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<WatermarkPosition>(
            segments: const [
              ButtonSegment(
                value: WatermarkPosition.topLeft,
                icon: Icon(Icons.north_west),
              ),
              ButtonSegment(
                value: WatermarkPosition.topRight,
                icon: Icon(Icons.north_east),
              ),
              ButtonSegment(
                value: WatermarkPosition.bottomLeft,
                icon: Icon(Icons.south_west),
              ),
              ButtonSegment(
                value: WatermarkPosition.bottomRight,
                icon: Icon(Icons.south_east),
              ),
            ],
            selected: {settings.position},
            onSelectionChanged: (value) {
              controller.update(settings.copyWith(position: value.first));
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: settings.timestampPattern,
            decoration: const InputDecoration(
              labelText: 'Timestamp Format',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'dd-MMM-yyyy hh:mm a',
                child: Text('03-Jun-2026 02:26 PM'),
              ),
              DropdownMenuItem(
                value: 'yyyy-MM-dd HH:mm',
                child: Text('2026-06-03 14:26'),
              ),
              DropdownMenuItem(
                value: 'dd/MM/yyyy hh:mm a',
                child: Text('03/06/2026 02:26 PM'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                controller.update(settings.copyWith(timestampPattern: value));
              }
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.showAddress,
            title: const Text('Show Address'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showAddress: value)),
          ),
          SwitchListTile(
            value: settings.showCoordinates,
            title: const Text('Show Coordinates'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showCoordinates: value)),
          ),
          SwitchListTile(
            value: settings.showAccuracy,
            title: const Text('Show Accuracy'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showAccuracy: value)),
          ),
          SwitchListTile(
            value: settings.showMapPreview,
            title: const Text('Show Map Preview'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showMapPreview: value)),
          ),
        ],
      ),
    );
  }
}
