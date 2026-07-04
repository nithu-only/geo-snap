import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsService {
  static const _template = 'template';
  static const _position = 'position';
  static const _timestampPattern = 'timestampPattern';
  static const _showAddress = 'showAddress';
  static const _showCoordinates = 'showCoordinates';
  static const _showAccuracy = 'showAccuracy';
  static const _showMapPreview = 'showMapPreview';
  static const _flashMode = 'flashMode';
  static const _cameraLens = 'cameraLens';
  static const _showGrid = 'showGrid';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AppSettings.defaults();
    return AppSettings(
      template: WatermarkTemplate
          .values[prefs.getInt(_template) ?? defaults.template.index],
      position: WatermarkPosition
          .values[prefs.getInt(_position) ?? defaults.position.index],
      timestampPattern:
          prefs.getString(_timestampPattern) ?? defaults.timestampPattern,
      showAddress: prefs.getBool(_showAddress) ?? defaults.showAddress,
      showCoordinates:
          prefs.getBool(_showCoordinates) ?? defaults.showCoordinates,
      showAccuracy: prefs.getBool(_showAccuracy) ?? defaults.showAccuracy,
      showMapPreview: prefs.getBool(_showMapPreview) ?? defaults.showMapPreview,
      flashMode: FlashMode
          .values[prefs.getInt(_flashMode) ?? defaults.flashMode.index],
      cameraLens: CameraLens
          .values[prefs.getInt(_cameraLens) ?? defaults.cameraLens.index],
      showGrid: prefs.getBool(_showGrid) ?? defaults.showGrid,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_template, settings.template.index);
    await prefs.setInt(_position, settings.position.index);
    await prefs.setString(_timestampPattern, settings.timestampPattern);
    await prefs.setBool(_showAddress, settings.showAddress);
    await prefs.setBool(_showCoordinates, settings.showCoordinates);
    await prefs.setBool(_showAccuracy, settings.showAccuracy);
    await prefs.setBool(_showMapPreview, settings.showMapPreview);
    await prefs.setInt(_flashMode, settings.flashMode.index);
    await prefs.setInt(_cameraLens, settings.cameraLens.index);
    await prefs.setBool(_showGrid, settings.showGrid);
  }
}
