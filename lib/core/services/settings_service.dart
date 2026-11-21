import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../utils/coordinate_formatter.dart';

class SettingsService {
  static const _template = 'template';
  static const _position = 'position';
  static const _timestampPattern = 'timestampPattern';
  static const _showAddress = 'showAddress';
  static const _showCoordinates = 'showCoordinates';
  static const _showAccuracy = 'showAccuracy';
  static const _showMapPreview = 'showMapPreview';
  static const _showAltitude = 'showAltitude';
  static const _showTimestamp = 'showTimestamp';
  static const _showCompass = 'showCompass';
  static const _watermarkTextColor = 'watermarkTextColor';
  static const _watermarkBgColor = 'watermarkBgColor';
  static const _watermarkBgOpacity = 'watermarkBgOpacity';
  static const _watermarkFontScale = 'watermarkFontScale';
  static const _flashMode = 'flashMode';
  static const _cameraLens = 'cameraLens';
  static const _showGrid = 'showGrid';
  static const _showLevel = 'showLevel';
  static const _coordinateFormat = 'coordinateFormat';
  static const _customNote = 'customNote';
  static const _timerSeconds = 'timerSeconds';
  static const _saveFolder = 'saveFolder';
  static const _saveFolderUri = 'saveFolderUri';
  static const _saveFolderLabel = 'saveFolderLabel';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = AppSettings.defaults();
    final formatIndex = prefs.getInt(_coordinateFormat);
    final coordFormat = (formatIndex != null && formatIndex >= 0 && formatIndex < CoordinateFormat.values.length)
        ? CoordinateFormat.values[formatIndex]
        : defaults.coordinateFormat;

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
      showAltitude: prefs.getBool(_showAltitude) ?? defaults.showAltitude,
      showTimestamp: prefs.getBool(_showTimestamp) ?? defaults.showTimestamp,
      showCompass: prefs.getBool(_showCompass) ?? defaults.showCompass,
      watermarkTextColor: prefs.getString(_watermarkTextColor) ?? defaults.watermarkTextColor,
      watermarkBgColor: prefs.getString(_watermarkBgColor) ?? defaults.watermarkBgColor,
      watermarkBgOpacity: prefs.getDouble(_watermarkBgOpacity) ?? defaults.watermarkBgOpacity,
      watermarkFontScale: prefs.getDouble(_watermarkFontScale) ?? defaults.watermarkFontScale,
      flashMode: FlashMode
          .values[prefs.getInt(_flashMode) ?? defaults.flashMode.index],
      cameraLens: CameraLens
          .values[prefs.getInt(_cameraLens) ?? defaults.cameraLens.index],
      showGrid: prefs.getBool(_showGrid) ?? defaults.showGrid,
      showLevel: prefs.getBool(_showLevel) ?? defaults.showLevel,
      coordinateFormat: coordFormat,
      customNote: prefs.getString(_customNote) ?? defaults.customNote,
      timerSeconds: prefs.getInt(_timerSeconds) ?? defaults.timerSeconds,
      saveFolder: prefs.getString(_saveFolder) ?? defaults.saveFolder,
      saveFolderUri: prefs.getString(_saveFolderUri) ?? defaults.saveFolderUri,
      saveFolderLabel: prefs.getString(_saveFolderLabel) ?? defaults.saveFolderLabel,
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
    await prefs.setBool(_showAltitude, settings.showAltitude);
    await prefs.setBool(_showTimestamp, settings.showTimestamp);
    await prefs.setBool(_showCompass, settings.showCompass);
    await prefs.setString(_watermarkTextColor, settings.watermarkTextColor);
    await prefs.setString(_watermarkBgColor, settings.watermarkBgColor);
    await prefs.setDouble(_watermarkBgOpacity, settings.watermarkBgOpacity);
    await prefs.setDouble(_watermarkFontScale, settings.watermarkFontScale);
    await prefs.setInt(_flashMode, settings.flashMode.index);
    await prefs.setInt(_cameraLens, settings.cameraLens.index);
    await prefs.setBool(_showGrid, settings.showGrid);
    await prefs.setBool(_showLevel, settings.showLevel);
    await prefs.setInt(_coordinateFormat, settings.coordinateFormat.index);
    await prefs.setString(_customNote, settings.customNote);
    await prefs.setInt(_timerSeconds, settings.timerSeconds);
    await prefs.setString(_saveFolder, settings.saveFolder);
    await prefs.setString(_saveFolderUri, settings.saveFolderUri);
    await prefs.setString(_saveFolderLabel, settings.saveFolderLabel);
  }

  Future<List<String>> loadCustomFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('customFolders') ?? <String>[];
  }

  Future<void> saveCustomFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customFolders', folders);
  }
}
