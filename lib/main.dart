import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/services/location_service.dart';
import 'core/services/map_thumbnail_service.dart';
import 'core/services/native_location_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/storage_service.dart';
import 'core/state/gallery_controller.dart';
import 'core/state/location_controller.dart';
import 'core/state/settings_controller.dart';
import 'features/camera/presentation/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GeoSnapApp());
}

class GeoSnapApp extends StatelessWidget {
  const GeoSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsController(SettingsService())..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationController(
            LocationService(),
            NativeLocationService(),
            MapThumbnailService(),
          )..start(),
        ),
        ChangeNotifierProvider(
          create: (_) => GalleryController(StorageService()),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0B6E69),
            brightness: Brightness.light,
          ),
          cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4DB6AC),
            brightness: Brightness.dark,
          ),
          cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
