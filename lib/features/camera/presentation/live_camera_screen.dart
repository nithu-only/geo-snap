import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_settings.dart';
import '../../../core/models/gallery_photo.dart';
import '../../../core/models/location_snapshot.dart';
import '../../../core/services/compass_service.dart';
import '../../../core/state/gallery_controller.dart';
import '../../../core/state/location_controller.dart';
import '../../../core/state/settings_controller.dart';
import '../../gallery/presentation/gallery_screen.dart';
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

  // Premium Toast state variables
  bool _showToast = false;
  String _toastTitle = '';
  String _toastSubtitle = '';
  bool _toastSuccess = true;
  Timer? _toastTimer;

  // Last shot preview
  GalleryPhoto? _lastPhoto;
  Uint8List? _lastPhotoBytes;

  // Self-Timer state
  bool _timerActive = false;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  // Zoom state
  double _currentZoom = 0.0;
  double _baseZoom = 0.0;
  bool _showZoomSlider = false;
  Timer? _zoomSliderTimer;

  // Focus state
  Offset? _focusPoint;
  bool _showFocusRing = false;
  double _focusRingScale = 1.0;
  Timer? _focusRingTimer;

  // Compass state
  final CompassService _compassService = CompassService();
  StreamSubscription<double>? _compassSubscription;
  double _currentHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _requestPermission();
    _compassService.startListening();
    _compassSubscription = _compassService.compassStream.listen((heading) {
      if (mounted) {
        setState(() {
          _currentHeading = heading;
        });
      }
    });
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _compassService.dispose();
    _flipController.dispose();
    _toastTimer?.cancel();
    _countdownTimer?.cancel();
    _zoomSliderTimer?.cancel();
    _focusRingTimer?.cancel();
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

  // Shutter Flash feedback state
  bool _showShutterFlash = false;

  void _triggerShutterFlash() {
    setState(() => _showShutterFlash = true);
    Timer(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() => _showShutterFlash = false);
      }
    });
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
      case 'onShutterTaken':
        if (mounted) {
          setState(() => _captureQueued = false);
        }
      case 'onPhotoSaved':
        setState(() => _captureQueued = false);
        final currentSettings = context.read<SettingsController>().settings;
        final folderPath = currentSettings.saveFolderUri.isNotEmpty
            ? 'Picked: ${currentSettings.saveFolderLabel}'
            : currentSettings.saveFolder.isNotEmpty
                ? 'Pictures/GeoSnap/${currentSettings.saveFolder}/'
                : 'Pictures/GeoSnap/';
        _showMessage('Photo Saved', subtitle: 'Saved to $folderPath');
        _refreshLastPhoto();
      case 'onPhotoError':
        setState(() => _captureQueued = false);
        _showMessage('Unable to Save Photo', subtitle: 'An error occurred during save', isSuccess: false);
      case 'onCameraError':
        setState(() {
          _captureQueued = false;
          _error = call.arguments?.toString() ?? 'Camera unavailable.';
        });
    }
  }

  void _onShutterPressed() {
    if (_timerActive || _captureQueued) return;

    final settings = context.read<SettingsController>().settings;
    if (settings.timerSeconds == 0) {
      _capture();
    } else {
      _startCountdown(settings.timerSeconds);
    }
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() {
      _timerActive = true;
      _secondsRemaining = seconds;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
        SystemSound.play(SystemSoundType.click);
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _timerActive = false;
        });
        _capture();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _timerActive = false;
      _secondsRemaining = 0;
    });
    _showMessage('Timer Cancelled', subtitle: 'Photo capture aborted');
  }

  void _capture() {
    final channel = _cameraChannel;
    final locationController = context.read<LocationController>();
    final location = locationController.captureSnapshot();
    if (channel == null || !_cameraReady || _captureQueued) {
      return;
    }
    if (location == null) {
      _showMessage('GPS Location Not Ready', subtitle: 'Please wait for a satellite lock', isSuccess: false);
      return;
    }
    if (!locationController.hasCaptureAccuracy) {
      _showMessage('Poor GPS Accuracy', subtitle: 'Wait for accuracy below 20m', isSuccess: false);
      return;
    }

    HapticFeedback.lightImpact();
    _triggerShutterFlash();

    final settings = context.read<SettingsController>().settings;
    setState(() => _captureQueued = true);
    unawaited(
      channel
          .invokeMethod<bool>('capture', {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'altitude': location.altitude,
            'accuracy': location.accuracy,
            'heading': location.heading > 0 ? location.heading : _currentHeading,
            'capturedAtMillis': DateTime.now().millisecondsSinceEpoch,
            'address': location.fullAddress,
            'template': settings.template.index,
            'position': settings.position.index,
            'timestampPattern': settings.timestampPattern,
            'showAddress': settings.showAddress,
            'showCoordinates': settings.showCoordinates,
            'showAccuracy': settings.showAccuracy,
            'showMapPreview': settings.showMapPreview,
            'showAltitude': settings.showAltitude,
            'showTimestamp': settings.showTimestamp,
            'showCompass': settings.showCompass,
            'textColor': settings.watermarkTextColor,
            'bgColor': settings.watermarkBgColor,
            'bgOpacity': settings.watermarkBgOpacity,
            'fontScale': settings.watermarkFontScale,
            'mapBytes': settings.showMapPreview
                ? locationController.cachedMapBytes
                : null,
            'addressHeader': settings.customNote.isNotEmpty
                ? settings.customNote
                : location.headerAddress,
            'addressBody': location.bodyAddress,
            'saveFolder': settings.saveFolder,
            'saveFolderUri': settings.saveFolderUri,
          })
          .then((accepted) {
            if (mounted && accepted != true) {
              setState(() => _captureQueued = false);
            }
          })
          .catchError((Object _) {
            if (mounted) {
              setState(() => _captureQueued = false);
              _showMessage('Unable to Save Photo', subtitle: 'An error occurred during save', isSuccess: false);
            }
          }),
    );
  }

  void _toggleFlash(AppSettings settings) {
    final controller = context.read<SettingsController>();
    final nextFlash = FlashMode.values[(settings.flashMode.index + 1) % 3];
    controller.update(settings.copyWith(flashMode: nextFlash));
    _cameraChannel?.invokeMethod('setFlashMode', {'flashMode': nextFlash.index});
    _showMessage('Flash Updated', subtitle: 'Mode set to ${nextFlash.name.toUpperCase()}');
  }

  void _toggleGrid(AppSettings settings) {
    final controller = context.read<SettingsController>();
    controller.update(settings.copyWith(showGrid: !settings.showGrid));
    _showMessage('Grid Updated', subtitle: 'Grid lines set to ${(!settings.showGrid) ? 'ON' : 'OFF'}');
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

  void _updateZoom(double zoom) {
    if (!_cameraReady || _cameraChannel == null) return;
    setState(() {
      _currentZoom = zoom;
      _showZoomSlider = true;
    });
    _cameraChannel!.invokeMethod('setZoom', {'zoom': zoom});
    _zoomSliderTimer?.cancel();
    _zoomSliderTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showZoomSlider = false);
      }
    });
  }

  void _triggerFocus(TapUpDetails details, BoxConstraints constraints) {
    if (!_cameraReady || _cameraChannel == null || _captureQueued || _timerActive) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPosition = details.localPosition;
    final x = (localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final y = (localPosition.dy / constraints.maxHeight).clamp(0.0, 1.0);

    setState(() {
      _focusPoint = localPosition;
      _showFocusRing = true;
      _focusRingScale = 1.3;
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _focusRingScale = 1.0;
        });
      }
    });

    _cameraChannel!.invokeMethod('focusAtPoint', {'x': x, 'y': y});

    _focusRingTimer?.cancel();
    _focusRingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showFocusRing = false);
      }
    });
  }

  void _showMessage(String title, {String subtitle = '', bool isSuccess = true}) {
    _toastTimer?.cancel();
    setState(() {
      _toastTitle = title;
      _toastSubtitle = subtitle;
      _toastSuccess = isSuccess;
      _showToast = true;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  Future<void> _refreshLastPhoto() async {
    final galleryController = context.read<GalleryController>();
    await galleryController.load();
    final photos = galleryController.photos;
    if (photos.isNotEmpty && mounted) {
      final newest = photos.first;
      final bytes = await galleryController.bytesFor(newest);
      if (mounted) {
        setState(() {
          _lastPhoto = newest;
          _lastPhotoBytes = bytes;
        });
      }
    }
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

        // Shutter Flash Feedback Animation
        if (_showShutterFlash)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),

        // Viewport Gesture Handler (Zoom & Focus)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _triggerFocus(details, constraints),
                onScaleStart: (details) {
                  _baseZoom = _currentZoom;
                },
                onScaleUpdate: (details) {
                  if (details.pointerCount == 2) {
                    final nextZoom = (_baseZoom + (details.scale - 1.0) * 0.5).clamp(0.0, 1.0);
                    _updateZoom(nextZoom);
                  }
                },
              );
            },
          ),
        ),

        // Focus Ring Overlay
        if (_showFocusRing && _focusPoint != null)
          Positioned(
            left: _focusPoint!.dx - 36,
            top: _focusPoint!.dy - 36,
            child: AnimatedScale(
              scale: _focusRingScale,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutBack,
              child: IgnorePointer(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.amberAccent, width: 2),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.amberAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Zoom Slider Overlay
        Positioned(
          right: 16,
          top: 150,
          bottom: 150,
          child: AnimatedOpacity(
            opacity: _showZoomSlider ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_showZoomSlider,
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    _ZoomButton(label: '4x', active: _currentZoom >= 0.6, onTap: () => _updateZoom(0.66)),
                    _ZoomButton(label: '2x', active: _currentZoom >= 0.25 && _currentZoom < 0.6, onTap: () => _updateZoom(0.33)),
                    _ZoomButton(label: '1x', active: _currentZoom < 0.25, onTap: () => _updateZoom(0.0)),
                    const Spacer(),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.tealAccent,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.tealAccent,
                            trackHeight: 3.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7.0),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                          ),
                          child: Slider(
                            value: _currentZoom,
                            min: 0.0,
                            max: 1.0,
                            onChanged: _updateZoom,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

        // Countdown Timer Overlay
        if (_timerActive)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey<int>(_secondsRemaining),
                      tween: Tween<double>(begin: 1.5, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: child,
                        );
                      },
                      child: Text(
                        '$_secondsRemaining',
                        style: const TextStyle(
                          color: Colors.tealAccent,
                          fontSize: 120,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      onPressed: _cancelCountdown,
                    ),
                  ],
                ),
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
                // GPS Satellite Lock Indicator
                _GpsSatelliteIndicator(
                  location: location,
                  hasLock: hasLock,
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
                // Quick controls (Folder, Zoom level)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FolderSelectionBadge(
                      folderName: settings.saveFolderUri.isNotEmpty
                          ? settings.saveFolderLabel
                          : settings.saveFolder.isNotEmpty
                              ? settings.saveFolder
                              : 'Default',
                      onTap: _showFolderSelectionSheet,
                    ),
                    const SizedBox(width: 12),
                    _QuickZoomPill(
                      zoom: _currentZoom,
                      onTap: () {
                        double next;
                        if (_currentZoom < 0.1) {
                          next = 0.33;
                        } else if (_currentZoom < 0.5) {
                          next = 0.66;
                        } else {
                          next = 0.0;
                        }
                        _updateZoom(next);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                    // Last shot preview thumbnail (left spot)
                    _LastShotButton(
                      lastPhoto: _lastPhoto,
                      lastPhotoBytes: _lastPhotoBytes,
                      onTap: () {
                        if (_lastPhoto != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PhotoDetailScreen(
                                  photos: [_lastPhoto!],
                                  initialIndex: 0,
                                ),
                              ),
                            );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const GalleryScreen()),
                          );
                        }
                      },
                    ),

                    // Shutter button
                    _ShutterButton(
                      enabled: _cameraReady && !_captureQueued && hasLock && !_timerActive,
                      onPressed: _onShutterPressed,
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

        // Premium glassmorphic Toast notification overlay
        AnimatedPositioned(
          duration: const Duration(milliseconds: 375),
          curve: Curves.easeOutBack,
          top: _showToast ? MediaQuery.of(context).padding.top + 16 : -120,
          left: 20,
          right: 20,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _showToast ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _toastSuccess 
                      ? Colors.tealAccent.withValues(alpha: 0.3) 
                      : Colors.redAccent.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_toastSuccess ? Colors.tealAccent : Colors.redAccent)
                        .withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: (_toastSuccess ? Colors.tealAccent : Colors.redAccent)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _toastSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                          color: _toastSuccess ? Colors.tealAccent : Colors.redAccent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _toastTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (_toastSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                _toastSubtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
          if (_currentHeading > 0 || location.heading > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Bearing: ${(location.heading > 0 ? location : location.copyWithHeading(_currentHeading)).headingFormatted}',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
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

  void _showFolderSelectionSheet() {
    final settingsController = context.read<SettingsController>();
    final currentFolder = settingsController.settings.saveFolder;
    final folderList = settingsController.folders;
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Save Folder',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Photos will be saved under Pictures/GeoSnap/your_folder/ or chosen directory.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: const BorderSide(color: Colors.tealAccent, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.folder_shared_outlined),
                    label: const Text(
                      'Choose Custom Device Folder...',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    onPressed: () async {
                      try {
                        const channel = MethodChannel('geo_snap/media_store');
                        final result = await channel.invokeMethod<Map<dynamic, dynamic>>('pickDirectory');
                        if (result != null) {
                          final uri = result['uri'] as String;
                          final label = result['label'] as String;
                          await settingsController.update(
                            settingsController.settings.copyWith(
                              saveFolderUri: uri,
                              saveFolderLabel: label,
                              saveFolder: '',
                            ),
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      } catch (e) {
                        // ignore or show error
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'New folder name...',
                            hintStyle: const TextStyle(color: Colors.white30),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final name = textController.text.trim();
                          if (name.isNotEmpty) {
                            await settingsController.addFolder(name);
                            await settingsController.update(
                              settingsController.settings.copyWith(
                                saveFolder: name,
                                saveFolderUri: '',
                                saveFolderLabel: '',
                              ),
                            );
                            textController.clear();
                            if (context.mounted) {
                              setSheetState(() {});
                            }
                          }
                        },
                        child: const Text('Add & Use'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Folders List',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          if (settingsController.settings.saveFolderUri.isNotEmpty)
                            _buildFolderTile(
                              context,
                              'Device Folder: ${settingsController.settings.saveFolderLabel}',
                              settingsController.settings.saveFolderUri,
                              true,
                              () {},
                            ),
                          _buildFolderTile(
                            context,
                            'Default (Root)',
                            '',
                            currentFolder == '' && settingsController.settings.saveFolderUri.isEmpty,
                            () {
                              settingsController.update(
                                settingsController.settings.copyWith(
                                  saveFolder: '',
                                  saveFolderUri: '',
                                  saveFolderLabel: '',
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                          ),
                          ...folderList.map(
                            (folder) => _buildFolderTile(
                              context,
                              folder,
                              folder,
                              currentFolder == folder && settingsController.settings.saveFolderUri.isEmpty,
                              () {
                                settingsController.update(
                                  settingsController.settings.copyWith(
                                    saveFolder: folder,
                                    saveFolderUri: '',
                                    saveFolderLabel: '',
                                  ),
                                );
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFolderTile(
    BuildContext context,
    String title,
    String folderValue,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: isSelected ? Colors.tealAccent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.tealAccent : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.tealAccent) : null,
        onTap: onTap,
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

class _LastShotButton extends StatelessWidget {
  const _LastShotButton({
    required this.lastPhoto,
    required this.lastPhotoBytes,
    required this.onTap,
  });

  final GalleryPhoto? lastPhoto;
  final Uint8List? lastPhotoBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.7),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: lastPhotoBytes != null
              ? Image.memory(
                  lastPhotoBytes!,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.white.withValues(alpha: 0.08),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Colors.white70,
                    size: 26,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GpsSatelliteIndicator extends StatefulWidget {
  const _GpsSatelliteIndicator({
    required this.location,
    required this.hasLock,
  });

  final LocationSnapshot? location;
  final bool hasLock;

  @override
  State<_GpsSatelliteIndicator> createState() => _GpsSatelliteIndicatorState();
}

class _GpsSatelliteIndicatorState extends State<_GpsSatelliteIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasGps = widget.location != null;
    final isLocked = widget.hasLock;

    final Color statusColor = !hasGps
        ? Colors.redAccent
        : !isLocked
            ? Colors.orangeAccent
            : Colors.tealAccent;

    final String label = !hasGps
        ? 'NO GPS'
        : '${widget.location!.accuracy.toStringAsFixed(0)}m';

    final IconData icon = !hasGps
        ? Icons.gps_off
        : !isLocked
            ? Icons.satellite_alt
            : Icons.gps_fixed;

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: statusColor, size: 18),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );

    if (!isLocked) {
      child = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnimation.value,
            child: child,
          );
        },
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: child,
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.tealAccent : Colors.white12,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black87 : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _QuickZoomPill extends StatelessWidget {
  const _QuickZoomPill({
    required this.zoom,
    required this.onTap,
  });

  final double zoom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String label = '1.0x';
    if (zoom >= 0.6) {
      label = '4.0x';
    } else if (zoom >= 0.25) {
      label = '2.0x';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.tealAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _FolderSelectionBadge extends StatelessWidget {
  const _FolderSelectionBadge({
    required this.folderName,
    required this.onTap,
  });

  final String folderName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_open_outlined,
              color: Colors.tealAccent,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              folderName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
