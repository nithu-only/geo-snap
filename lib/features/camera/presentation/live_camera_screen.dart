import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/state/location_controller.dart';
import '../../../core/state/settings_controller.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  MethodChannel? _cameraChannel;
  bool _permissionReady = false;
  bool _cameraReady = false;
  bool _captureQueued = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final permission = await Permission.camera.request();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionReady = permission.isGranted;
      _error = permission.isGranted ? null : 'Camera permission was denied.';
    });
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('geotag_camera/camera_$id');
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (!_permissionReady) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              AndroidView(
                viewType: 'geotag_camera/native_camera',
                onPlatformViewCreated: _onPlatformViewCreated,
                creationParamsCodec: const StandardMessageCodec(),
              ),
              if (!_cameraReady)
                const ColoredBox(
                  color: Colors.black,
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
        _CameraControls(
          enabled: _cameraReady && !_captureQueued,
          onCapture: _capture,
        ),
      ],
    );
  }
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({required this.enabled, required this.onCapture});

  final bool enabled;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 112,
          child: Center(
            child: Semantics(
              button: true,
              enabled: enabled,
              label: 'Take photo',
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: enabled ? onCapture : null,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.onSurface, width: 4),
                      ),
                      padding: const EdgeInsets.all(7),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: colors.onPrimary,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
