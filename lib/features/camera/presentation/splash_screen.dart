import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../core/state/location_controller.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoGlow;
  
  bool _checkingPermissions = true;
  bool _hasPermissions = false;
  String _statusMessage = 'Initializing GeoSnap...';

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOutBack),
    );

    _logoGlow = Tween<double>(begin: 4.0, end: 16.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _checkCurrentPermissions();
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _checkCurrentPermissions() async {
    setState(() {
      _checkingPermissions = true;
      _statusMessage = 'Verifying permissions...';
    });

    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.location.status;

    if (cameraStatus.isGranted && locationStatus.isGranted) {
      setState(() {
        _hasPermissions = true;
        _checkingPermissions = false;
        _statusMessage = 'GPS Warming up...';
      });
      // Warm up the location tracking early
      if (mounted) {
        context.read<LocationController>().warmUp();
      }
      // Hold splash screen for 1.5 seconds for a premium feel
      Timer(const Duration(milliseconds: 1500), _navigateToHome);
    } else {
      setState(() {
        _hasPermissions = false;
        _checkingPermissions = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _statusMessage = 'Requesting camera and location...';
    });

    final statuses = await [
      Permission.camera,
      Permission.location,
    ].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final locationGranted = statuses[Permission.location]?.isGranted ?? false;

    if (cameraGranted && locationGranted) {
      setState(() {
        _hasPermissions = true;
        _statusMessage = 'Permissions granted! Starting GPS...';
      });
      if (mounted) {
        context.read<LocationController>().warmUp();
      }
      Timer(const Duration(milliseconds: 1000), _navigateToHome);
    } else {
      setState(() {
        _statusMessage = 'Permissions are required to run GeoSnap.';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and location permissions are required.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.surface,
              colors.surfaceContainerLowest,
              colors.primary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  // Animated Pulsing Shutter Logo
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primaryContainer.withValues(alpha: 0.3),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: _logoGlow.value,
                              spreadRadius: _logoGlow.value / 2,
                            ),
                          ],
                        ),
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Center(
                            child: Icon(
                              Icons.camera,
                              size: 68,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  // App Title
                  Text(
                    'GeoSnap',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: colors.onSurface,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Private GPS Watermark Camera',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 48),
                  // Dynamic State UI
                  if (_checkingPermissions)
                    Column(
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    )
                  else if (_hasPermissions)
                    Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: colors.primary, size: 32),
                        const SizedBox(height: 12),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  else
                    _buildPermissionGate(colors),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionGate(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Permissions Required',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'To stamp real-time coordinates, location data, and map thumbnails onto captured photos, GeoSnap needs permission to access the camera and precise location.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.security_outlined),
            label: const Text(
              'Grant Permissions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onPressed: _requestPermissions,
          ),
        ],
      ),
    );
  }
}
