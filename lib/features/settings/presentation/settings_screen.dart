import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/state/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _noteController;
  late TextEditingController _folderController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    _noteController = TextEditingController(text: settings.customNote);
    _folderController = TextEditingController(text: settings.saveFolder);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _folderController.dispose();
    super.dispose();
  }

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
              ButtonSegment(
                value: WatermarkTemplate.minimal,
                label: Text('Minimal'),
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
          Text(
            'Custom Stamp Note / Project Name',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Enter project name or custom text...',
              border: OutlineInputBorder(),
              helperText: 'Stamps this custom text at the top of the photo details.',
            ),
            onChanged: (value) {
              controller.update(settings.copyWith(customNote: value));
            },
          ),
          const SizedBox(height: 20),
          if (settings.saveFolderUri.isNotEmpty) ...[
            ListTile(
              tileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Icon(Icons.folder_shared, color: Theme.of(context).colorScheme.primary),
              title: const Text('Active Device Folder'),
              subtitle: Text(settings.saveFolderLabel),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.update(
                    settings.copyWith(
                      saveFolderUri: '',
                      saveFolderLabel: '',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            'Default Save Folder Name',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _folderController,
            decoration: const InputDecoration(
              hintText: 'Enter folder name (e.g. Project-A)...',
              border: OutlineInputBorder(),
              helperText: 'Images will be saved under Pictures/GeoSnap/<folder_name>/',
            ),
            onChanged: (value) {
              final clean = value.trim();
              controller.update(settings.copyWith(saveFolder: clean));
              if (clean.isNotEmpty) {
                controller.addFolder(clean);
              }
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
          SwitchListTile(
            value: settings.showAltitude,
            title: const Text('Show Altitude'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showAltitude: value)),
          ),
          SwitchListTile(
            value: settings.showTimestamp,
            title: const Text('Show Timestamp'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showTimestamp: value)),
          ),
          const Divider(height: 32),
          Text(
            'Default Camera Settings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Default Flash Mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<FlashMode>(
            segments: const [
              ButtonSegment(
                value: FlashMode.off,
                icon: Icon(Icons.flash_off),
                label: Text('Off'),
              ),
              ButtonSegment(
                value: FlashMode.on,
                icon: Icon(Icons.flash_on),
                label: Text('On'),
              ),
              ButtonSegment(
                value: FlashMode.auto,
                icon: Icon(Icons.flash_auto),
                label: Text('Auto'),
              ),
            ],
            selected: {settings.flashMode},
            onSelectionChanged: (value) {
              controller.update(settings.copyWith(flashMode: value.first));
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Default Camera Lens',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<CameraLens>(
            segments: const [
              ButtonSegment(
                value: CameraLens.back,
                icon: Icon(Icons.camera_rear),
                label: Text('Back Camera'),
              ),
              ButtonSegment(
                value: CameraLens.front,
                icon: Icon(Icons.camera_front),
                label: Text('Front Camera'),
              ),
            ],
            selected: {settings.cameraLens},
            onSelectionChanged: (value) {
              controller.update(settings.copyWith(cameraLens: value.first));
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.showGrid,
            title: const Text('Show Grid Lines'),
            subtitle: const Text('Displays a 3x3 rule-of-thirds grid on the camera'),
            onChanged: (value) =>
                controller.update(settings.copyWith(showGrid: value)),
          ),
        ],
      ),
    );
  }
}
