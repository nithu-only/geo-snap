import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._service);

  final SettingsService _service;
  AppSettings _settings = AppSettings.defaults();
  List<String> _folders = [];
  bool _loaded = false;

  AppSettings get settings => _settings;
  List<String> get folders => _folders;
  bool get loaded => _loaded;

  Future<void> load() async {
    _settings = await _service.load();
    _folders = await _service.loadCustomFolders();
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _service.save(settings);
  }

  Future<void> addFolder(String folder) async {
    final clean = folder.trim();
    if (clean.isEmpty || _folders.contains(clean)) return;
    _folders.add(clean);
    notifyListeners();
    await _service.saveCustomFolders(_folders);
  }
}
