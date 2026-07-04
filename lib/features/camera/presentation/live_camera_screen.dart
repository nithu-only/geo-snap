import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/state/location_controller.dart';
import '../../../core/state/settings_controller.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/location_snapshot.dart';
import '../../settings/presentation/settings_screen.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> with SingleTickerProviderStateMixin {
  MethodChannel? _cameraChannel;
  bool _permissionReady = false;
  bool _cameraReady = false;
  bool _captureQueued = false;
  String? _error;
  
  late AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _requestPermission();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final camera = await Permission.camera.status;
    if (!camera.isGranted) {
      final permission = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _permissionReady = permission.isGranted;
        _error = permission.isGranted ? null : 'Camera permission was denied.';
      });
    } else {
      setState(() {
        _permissionReady = true;
        _error = null;
      });
    }
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('geo_snap/camera_$id');
    channel.setMethodCallHandler(_onNativeCameraEvent);
    setState(() => _cameraChannel = channel);
  }

  Future<void> _onNativeCameraEvent(MethodCall call) async {
    if (!mounted) {
      return;
    }
    switch (call.method) {
      case 'onCameraReady':
        setState(() {
          _cameraReady = true;
          _error = null;
        });
      case 'onPhotoSaved':
        setState(() => _captureQueued = false);
        _showMessage('Photo Saved');
      case 'onPhotoError':
        setState(() => _captureQueued = false);
        _showMessage('Unable to save photo');
      case 'onCameraError':
        setState(() {
          _captureQueued = false;
          _error = call.arguments?.toString() ?? 'Camera unavailable.';
        });
    }
  }

  void _capture() {
    final channel = _cameraChannel;
    final locationController = context.read<LocationController>();
    final location = locationController.captureSnapshot();
    if (channel == null || !_cameraReady || _captureQueued) {
      return;
    }
    if (location == null) {
      _showMessage('Location is not available yet.');
      return;
    }
    if (!locationController.hasCaptureAccuracy) {
      _showMessage('GPS accuracy must be below 20m before capture.');
      return;
    }

    final settings = context.read<SettingsController>().settings;
    setState(() => _captureQueued = true);
    unawaited(
      channel
          .invokeMethod<bool>('capture', {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'altitude': location.altitude,
            'accuracy': location.accuracy,
            'capturedAtMillis': DateTime.now().millisecondsSinceEpoch,
            'address': location.fullAddress,
            'template': settings.template.index,
            'position': settings.position.index,
            'timestampPattern': settings.timestampPattern,
            'showAddress': settings.showAddress,
            'showCoordinates': settings.showCoordinates,
            'showAccuracy': settings.showAccuracy,
            'showMapPreview': settings.showMapPreview,
            'mapBytes': settings.showMapPreview
                ? locationController.cachedMapBytes
                : null,
          })
          .then((accepted) {
            if (mounted && accepted != true) {
              setState(() => _captureQueued = false);
            }
          })
          .catchError((Object _) {
            if (mounted) {
              setState(() => _captureQueued = false);
              _showMessage('Unable to capture photo');
            }
          }),
    );
  }

  void _toggleFlash(AppSettings settings) {
    final controller = context.read<SettingsController>();
    final nextFlash = FlashMode.values[(settings.flashMode.index + 1) % 3];
    controller.update(settings.copyWith(flashMode: nextFlash));
    _cameraChannel?.invokeMethod('setFlashMode', {'flashMode': nextFlash.index});
    _showMessage('Flash: ${nextFlash.name.toUpperCase()}');
  }

  void _toggleGrid(AppSettings settings) {
    final controller = context.read<SettingsController>();
    controller.update(settings.copyWith(showGrid: !settings.showGrid));
    _showMessage('Grid Lines: ${(!settings.showGrid) ? 'ON' : 'OFF'}');
  }

  void _flipCamera(AppSettings settings) {
    final controller = context.read<SettingsController>();
    final nextLens = settings.cameraLens == CameraLens.back ? CameraLens.front : CameraLens.back;
    
    _flipController.forward(from: 0.0);
    setState(() {
      _cameraReady = false; // Trigger loading overlay while camera re-binds
    });
    
    controller.update(settings.copyWith(cameraLens: nextLens));
    _cameraChannel?.invokeMethod('setCameraLens', {'cameraLens': nextLens.index});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(settings),
    );
  }

  Widget _buildBody(AppSettings settings) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }
    if (!_permissionReady) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final locationController = context.watch<LocationController>();
    final location = locationController.snapshot;
    final hasLock = locationController.hasCaptureAccuracy;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Viewport
        Positioned.fill(
          child: AndroidView(
            viewType: 'geo_snap/native_camera',
            onPlatformViewCreated: _onPlatformViewCreated,
            creationParams: {
              'flashMode': settings.flashMode.index,
              'cameraLens': settings.cameraLens.index,
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),
        ),

        // Grid Lines Overlay
        if (settings.showGrid)
          const Positioned.fill(
            child: IgnorePointer(
              child: _GridOverlay(),
            ),
          ),

        // Camera Loading overlay
        if (!_cameraReady)
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 16),
                  Text(
                    'Initializing Camera...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

        // Top Settings bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Button
                _GlassIconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Flash toggler
                _GlassIconButton(
                  icon: Icon(
                    settings.flashMode == FlashMode.off
                        ? Icons.flash_off
                        : settings.flashMode == FlashMode.on
                            ? Icons.flash_on
                            : Icons.flash_auto,
                    color: settings.flashMode == FlashMode.off
                        ? Colors.white54
                        : Colors.amberAccent,
                  ),
                  onPressed: () => _toggleFlash(settings),
                ),
                // Grid toggler
                _GlassIconButton(
                  icon: Icon(
                    settings.showGrid ? Icons.grid_on : Icons.grid_off,
                    color: settings.showGrid ? Colors.tealAccent : Colors.white54,
                  ),
                  onPressed: () => _toggleGrid(settings),
                ),
                // Settings Shortcut
                _GlassIconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),

        // GPS HUD & Bottom Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Real-time GPS Watermark HUD
                if (location != null)
                  _buildGpsHud(location, hasLock, locationController.message)
                else
                  _buildGpsConnectingHud(locationController.message),
                const SizedBox(height: 24),
                // Controls Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Grid or Aspect Ratio helper (left spot)
                    const SizedBox(width: 48, height: 48),

                    // Shutter button
                    _ShutterButton(
                      enabled: _cameraReady && !_captureQueued && hasLock,
                      onPressed: _capture,
                    ),

                    // Camera Flip (right spot)
                    RotationTransition(
                      turns: _flipController,
                      child: _GlassIconButton(
                        icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 28),
                        onPressed: () => _flipCamera(settings),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGpsHud(LocationSnapshot location, bool hasLock, String? statusMsg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasLock ? Colors.teal.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasLock ? Icons.gps_fixed : Icons.gps_not_fixed,
                color: hasLock ? Colors.tealAccent : Colors.orangeAccent,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusMsg ?? (hasLock ? 'GPS Locked' : 'Calibrating GPS...'),
                  style: TextStyle(
                    color: hasLock ? Colors.tealAccent : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Accuracy: ${location.accuracy.toStringAsFixed(1)}m',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 12),
          Text(
            'Lat: ${location.latitude.toStringAsFixed(6)}   Long: ${location.longitude.toStringAsFixed(6)}',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
          ),
          if (location.placeName != null || location.city != null) ...[
            const SizedBox(height: 4),
            Text(
              location.fullAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsConnectingHud(String? statusMsg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
          ),
          const SizedBox(width: 12),
          Text(
            statusMsg ?? 'Connecting to GPS...',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _GridOverlay extends StatelessWidget {
  const _GridOverlay();

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: 0.35);
    return Stack(
      children: [
        Row(
          children: [
            Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: color, width: 0.75))))),
            Expanded(child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: color, width: 0.75))))),
            Expanded(child: Container()),
          ],
        ),
        Column(
          children: [
            Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 0.75))))),
            Expanded(child: Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: color, width: 0.75))))),
            Expanded(child: Container()),
          ],
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onPressed});

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPressed : null,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4.5),
              ),
              padding: const EdgeInsets.all(6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? Colors.tealAccent : Colors.teal.withValues(alpha: 0.5),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: enabled ? Colors.black87 : Colors.white24,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
