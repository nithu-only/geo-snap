import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/state/settings_controller.dart';
import '../../../core/utils/coordinate_formatter.dart';

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
            title: 'Live Watermark Preview',
            children: [
              _WatermarkPreviewCard(settings: settings),
            ],
          ),
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
              const SizedBox(height: 16),
              Text(
                'Coordinate Format',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildPillSelector<CoordinateFormat>(
                selectedValue: settings.coordinateFormat,
                values: CoordinateFormat.values,
                labelBuilder: (val) {
                  switch (val) {
                    case CoordinateFormat.decimal:
                      return 'Decimal (DD)';
                    case CoordinateFormat.dms:
                      return 'DMS';
                    case CoordinateFormat.utm:
                      return 'UTM';
                  }
                },
                onSelected: (value) {
                  controller.update(settings.copyWith(coordinateFormat: value));
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.showLevel,
                title: const Text('Show Virtual Horizon (Level)', style: TextStyle(fontSize: 14)),
                subtitle: const Text('Displays an artificial leveling horizon on the camera', style: TextStyle(fontSize: 12)),
                onChanged: (value) =>
                    controller.update(settings.copyWith(showLevel: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WatermarkPreviewCard extends StatelessWidget {
  const _WatermarkPreviewCard({required this.settings});

  final AppSettings settings;

  Alignment _getAlignment(WatermarkPosition position) {
    switch (position) {
      case WatermarkPosition.topLeft:
        return Alignment.topLeft;
      case WatermarkPosition.topRight:
        return Alignment.topRight;
      case WatermarkPosition.bottomLeft:
        return Alignment.bottomLeft;
      case WatermarkPosition.bottomRight:
        return Alignment.bottomRight;
    }
  }

  Color _getTextColor(String color) {
    switch (color) {
      case 'black':
        return const Color(0xFF282D32);
      case 'yellow':
        return const Color(0xFFFFC629);
      default:
        return Colors.white;
    }
  }

  Color _getBgColor(String color) {
    switch (color) {
      case 'white':
        return Colors.white;
      case 'transparent':
        return Colors.transparent;
      default:
        return Colors.black;
    }
  }

  List<String> _buildPreviewLines(AppSettings settings) {
    final lines = <String>[];
    
    if (settings.template == WatermarkTemplate.gpsMapCamera) {
      if (settings.showAddress) {
        lines.add(settings.customNote.isNotEmpty ? settings.customNote : '123 Main St, Manhattan');
        lines.add('New York, NY, USA 🇺🇸');
      } else {
        lines.add('GeoSnap');
      }
      
      if (settings.showCoordinates) {
        lines.add(CoordinateFormatter.format(
          latitude: 40.712776,
          longitude: -74.005974,
          format: settings.coordinateFormat,
        ));
      }
      
      final extra = <String>[];
      if (settings.showAltitude) extra.add('Alt 12.5m');
      if (settings.showAccuracy) extra.add('Accuracy 4m');
      if (settings.showCompass) extra.add('Bearing 142° SE');
      if (extra.isNotEmpty) {
        lines.add(extra.join('   '));
      }
      
      if (settings.showTimestamp) {
        final now = DateTime.now();
        final dateStr = DateFormat('EEEE, dd/MM/yyyy hh:mm a').format(now);
        final offset = now.timeZoneOffset;
        final hours = offset.inHours.abs().toString().padLeft(2, '0');
        final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
        final sign = offset.isNegative ? '-' : '+';
        lines.add('$dateStr GMT $sign$hours:$minutes');
      }
    } else {
      if (settings.showAddress) {
        lines.add(settings.customNote.isNotEmpty ? settings.customNote : '123 Main St, New York, NY, USA 🇺🇸');
      } else {
        lines.add('GeoSnap');
      }
      
      if (settings.showCoordinates) {
        lines.add(CoordinateFormatter.format(
          latitude: 40.712776,
          longitude: -74.005974,
          format: settings.coordinateFormat,
        ));
      }
      
      if (settings.showAltitude) {
        lines.add('Alt: 12.5m');
      }
      
      if (settings.showTimestamp) {
        try {
          final formatted = DateFormat(settings.timestampPattern).format(DateTime.now());
          lines.add(formatted);
        } catch (_) {
          lines.add('07-Aug-2026 09:32 AM');
        }
      }
      
      if (settings.showAccuracy) {
        lines.add('Accuracy: 4m');
      }
      
      if (settings.showCompass) {
        lines.add('Bearing: 142° SE');
      }
    }
    
    return lines;
  }

  Widget _buildMapPlaceholder(AppSettings settings) {
    final isGpsTemplate = settings.template == WatermarkTemplate.gpsMapCamera;
    final width = isGpsTemplate ? 36.0 : 44.0;
    final height = isGpsTemplate ? 36.0 : 24.0;
    final radius = isGpsTemplate ? 4.0 : 3.0;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF14202D),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _MapGridPainter(),
            ),
          ),
          const Icon(
            Icons.location_on,
            color: Color(0xFFDC322F),
            size: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildWatermarkBody(AppSettings settings) {
    final lines = _buildPreviewLines(settings);
    final textColor = _getTextColor(settings.watermarkTextColor);
    final fontScale = settings.watermarkFontScale;
    
    if (settings.template == WatermarkTemplate.minimal) {
      final alignRight = (settings.position == WatermarkPosition.topRight || settings.position == WatermarkPosition.bottomRight);
      
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: lines.asMap().entries.map((entry) {
          final index = entry.key;
          final text = entry.value;
          final isTitle = index == 0;
          
          return Text(
            text,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              color: textColor,
              fontSize: (isTitle ? 9.5 : 8.0) * fontScale,
              fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
              shadows: [
                Shadow(
                  color: settings.watermarkTextColor == 'black' 
                      ? Colors.white.withValues(alpha: 0.5) 
                      : Colors.black.withValues(alpha: 0.8),
                  offset: const Offset(1.0, 1.0),
                  blurRadius: 2.0,
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
    
    final panelBgColor = _getBgColor(settings.watermarkBgColor);
    final panelBgOpacity = settings.watermarkBgOpacity;
    
    final showMap = settings.showMapPreview && 
        (settings.template == WatermarkTemplate.largePanel || settings.template == WatermarkTemplate.gpsMapCamera);
        
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showMap) ...[
          _buildMapPlaceholder(settings),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.asMap().entries.map((entry) {
              final index = entry.key;
              final text = entry.value;
              final isTitle = index == 0 && settings.template != WatermarkTemplate.compact;
              
              return Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isTitle 
                      ? (settings.watermarkTextColor == 'white' ? Colors.white : textColor)
                      : (settings.watermarkTextColor == 'white' ? Colors.white70 : textColor.withValues(alpha: 0.8)),
                  fontSize: (isTitle ? 9.0 : 7.5) * fontScale,
                  fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: panelBgColor.withValues(alpha: panelBgOpacity),
        borderRadius: BorderRadius.circular(6),
      ),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3C72),
            Color(0xFF2A5298),
            Color(0xFF487EB0),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PreviewGridPainter(),
                ),
              ),
            ),
            Align(
              alignment: _getAlignment(settings.position),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildWatermarkBody(settings),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
      
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
    
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;
    
    final step = size.width / 4;
    for (int i = 1; i <= 3; i++) {
      final x = i * step;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final stepY = size.height / 4;
    for (int i = 1; i <= 3; i++) {
      final y = i * stepY;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
