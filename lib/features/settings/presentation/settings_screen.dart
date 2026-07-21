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

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>().settings;
    _noteController = TextEditingController(text: settings.customNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPillSelector<T>({
    required T selectedValue,
    required List<T> values,
    required String Function(T) labelBuilder,
    required void Function(T) onSelected,
    Widget Function(T, bool isSelected)? customItemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: values.map((val) {
          final isSelected = val == selectedValue;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: customItemBuilder != null
                      ? customItemBuilder(val, isSelected)
                      : Text(
                          labelBuilder(val),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: 'Watermark Layout',
            children: [
              Text(
                'Watermark Template',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<WatermarkTemplate>(
                selectedValue: settings.template,
                values: WatermarkTemplate.values,
                labelBuilder: (val) {
                  switch (val) {
                    case WatermarkTemplate.compact: return 'Compact';
                    case WatermarkTemplate.largePanel: return 'Large';
                    case WatermarkTemplate.gpsMapCamera: return 'GPS';
                    case WatermarkTemplate.minimal: return 'Minimal';
                  }
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(template: value));
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Watermark Position',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<WatermarkPosition>(
                selectedValue: settings.position,
                values: WatermarkPosition.values,
                labelBuilder: (_) => '',
                customItemBuilder: (val, isSelected) {
                  IconData icon;
                  switch (val) {
                    case WatermarkPosition.topLeft: icon = Icons.north_west; break;
                    case WatermarkPosition.topRight: icon = Icons.north_east; break;
                    case WatermarkPosition.bottomLeft: icon = Icons.south_west; break;
                    case WatermarkPosition.bottomRight: icon = Icons.south_east; break;
                  }
                  return Icon(
                    icon,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  );
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(position: value));
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: settings.timestampPattern,
                decoration: const InputDecoration(
                  labelText: 'Timestamp Format',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
                  leading: Icon(
                    Icons.edit_note_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text(
                    'Custom Note / Project Title',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    settings.customNote.isNotEmpty
                        ? settings.customNote
                        : 'None (Tap to add custom stamp note)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: settings.customNote.isNotEmpty
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                  children: [
                    TextField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        hintText: 'Enter project name or custom text...',
                        border: OutlineInputBorder(),
                        helperText: 'Stamps this custom title onto saved photos.',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (value) {
                        controller.update(settings.copyWith(customNote: value));
                      },
                    ),
                  ],
                ),
              ),
              if (settings.saveFolderUri.isNotEmpty) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  tileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(Icons.folder_shared, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Active Device Folder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text(settings.saveFolderLabel, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.clear, size: 20),
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
              ],
            ],
          ),
          _buildSection(
            context,
            title: 'Watermark Styling',
            children: [
              Text(
                'Text Color',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<String>(
                selectedValue: settings.watermarkTextColor,
                values: const ['white', 'black', 'yellow'],
                labelBuilder: (val) => val,
                customItemBuilder: (val, isSelected) {
                  Color dotColor;
                  switch (val) {
                    case 'white': dotColor = Colors.white; break;
                    case 'black': dotColor = Colors.black; break;
                    case 'yellow': dotColor = Colors.amber; break;
                    default: dotColor = Colors.white;
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: val == 'white' && !isSelected
                                ? Colors.grey.shade400
                                : isSelected ? Colors.white30 : Colors.transparent,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        val[0].toUpperCase() + val.substring(1),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(watermarkTextColor: value));
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Background Style',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<String>(
                selectedValue: settings.watermarkBgColor,
                values: const ['black', 'white', 'transparent'],
                labelBuilder: (val) => val,
                customItemBuilder: (val, isSelected) {
                  Color previewColor;
                  switch (val) {
                    case 'black': previewColor = Colors.black; break;
                    case 'white': previewColor = Colors.white; break;
                    default: previewColor = Colors.transparent;
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (val != 'transparent')
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: previewColor,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: val == 'white' && !isSelected
                                  ? Colors.grey.shade400
                                  : isSelected ? Colors.white30 : Colors.transparent,
                              width: 1,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.layers_clear_outlined,
                          size: 12,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        val == 'transparent' ? 'Clear' : val[0].toUpperCase() + val.substring(1),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(watermarkBgColor: value));
                },
              ),
              if (settings.watermarkBgColor != 'transparent') ...[
                const SizedBox(height: 16),
                Text(
                  'Background Opacity',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: settings.watermarkBgOpacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 10,
                        label: '${(settings.watermarkBgOpacity * 100).toInt()}%',
                        onChanged: (val) {
                          controller.update(settings.copyWith(watermarkBgOpacity: val));
                        },
                      ),
                    ),
                    Text(
                      '${(settings.watermarkBgOpacity * 100).toInt()}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Font Size Scale',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<double>(
                selectedValue: settings.watermarkFontScale,
                values: const [0.8, 1.0, 1.2, 1.4],
                labelBuilder: (val) => '',
                customItemBuilder: (val, isSelected) {
                  String text;
                  switch (val) {
                    case 0.8: text = 'S'; break;
                    case 1.0: text = 'M'; break;
                    case 1.2: text = 'L'; break;
                    case 1.4: text = 'XL'; break;
                    default: text = 'M';
                  }
                  return Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(watermarkFontScale: value));
                },
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Watermark Metadata Toggles',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showAddress,
                title: const Text('Show Address', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showAddress: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showCoordinates,
                title: const Text('Show Coordinates', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showCoordinates: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showAccuracy,
                title: const Text('Show Accuracy', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showAccuracy: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showMapPreview,
                title: const Text('Show Map Preview', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showMapPreview: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showAltitude,
                title: const Text('Show Altitude', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showAltitude: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showTimestamp,
                title: const Text('Show Timestamp', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showTimestamp: value)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showCompass,
                title: const Text('Show Compass / Bearing (e.g. 142° SE)', style: TextStyle(fontSize: 14)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showCompass: value)),
              ),
            ],
          ),
          _buildSection(
            context,
            title: 'Default Camera Settings',
            children: [
              Text(
                'Default Flash Mode',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<FlashMode>(
                selectedValue: settings.flashMode,
                values: const [FlashMode.off, FlashMode.on, FlashMode.auto],
                labelBuilder: (val) => val == FlashMode.off ? 'Off' : val == FlashMode.on ? 'On' : 'Auto',
                customItemBuilder: (val, isSelected) {
                  IconData icon;
                  String label;
                  switch (val) {
                    case FlashMode.off: icon = Icons.flash_off; label = 'Off'; break;
                    case FlashMode.on: icon = Icons.flash_on; label = 'On'; break;
                    case FlashMode.auto: icon = Icons.flash_auto; label = 'Auto'; break;
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(flashMode: value));
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Default Camera Lens',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<CameraLens>(
                selectedValue: settings.cameraLens,
                values: const [CameraLens.back, CameraLens.front],
                labelBuilder: (val) => val == CameraLens.back ? 'Back' : 'Front',
                customItemBuilder: (val, isSelected) {
                  IconData icon;
                  String label;
                  switch (val) {
                    case CameraLens.back: icon = Icons.camera_rear; label = 'Back'; break;
                    case CameraLens.front: icon = Icons.camera_front; label = 'Front'; break;
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(cameraLens: value));
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showGrid,
                title: const Text('Show Grid Lines', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Displays a 3x3 rule-of-thirds grid on the camera', style: TextStyle(fontSize: 12)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showGrid: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
