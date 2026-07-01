import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._service);

  final SettingsService _service;
  AppSettings _settings = AppSettings.defaults();
  bool _loaded = false;

  AppSettings get settings => _settings;
  bool get loaded => _loaded;

  Future<void> load() async {
    _settings = await _service.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _service.save(settings);
  }
}
