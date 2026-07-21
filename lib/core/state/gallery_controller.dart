import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/gallery_photo.dart';
import '../services/storage_service.dart';

class GalleryController extends ChangeNotifier {
  GalleryController(this._storageService);

  final StorageService _storageService;

  List<GalleryPhoto> _photos = const [];
  String _query = '';
  bool _loading = false;
  String? _lastSaveFolder;
  String? _lastSaveFolderUri;

  List<GalleryPhoto> get photos {
    if (_query.trim().isEmpty) {
      return _photos;
    }
    final q = _query.trim().toLowerCase();
    return _photos.where((photo) {
      final date = DateFormat(
        'yyyy-MM-dd dd-MMM-yyyy',
      ).format(photo.createdAt).toLowerCase();
      return date.contains(q) || photo.name.toLowerCase().contains(q);
    }).toList();
  }

  bool get loading => _loading;
  String get query => _query;

  final Map<String, Uint8List> _thumbnailCache = {};

  Future<void> load({String? saveFolder, String? saveFolderUri}) async {
    _lastSaveFolder = saveFolder;
    _lastSaveFolderUri = saveFolderUri;
    _loading = true;
    _thumbnailCache.clear();
    notifyListeners();
    await _requestMediaPermission();
    _photos = await _storageService.listPhotos(saveFolder: saveFolder, saveFolderUri: saveFolderUri);
    _loading = false;
    notifyListeners();
  }

  void search(String value) {
    _query = value;
    notifyListeners();
  }

  Future<Uint8List> bytesFor(GalleryPhoto photo) =>
      _storageService.readBytes(photo.uri);

  Future<Uint8List> thumbnailFor(GalleryPhoto photo) async {
    final cached = _thumbnailCache[photo.uri];
    if (cached != null) {
      return cached;
    }
    final bytes = await _storageService.readThumbnail(photo.uri);
    _thumbnailCache[photo.uri] = bytes;
    return bytes;
  }

  Future<void> delete(GalleryPhoto photo) async {
    await _storageService.delete(photo.uri);
    await load(saveFolder: _lastSaveFolder, saveFolderUri: _lastSaveFolderUri);
  }

  Future<void> share(GalleryPhoto photo) => _storageService.share(photo);

  Future<void> _requestMediaPermission() async {
    final photos = await Permission.photos.request();
    if (!photos.isGranted) {
      await Permission.storage.request();
    }
    try {
      await Permission.accessMediaLocation.request();
    } catch (_) {}
  }
}
