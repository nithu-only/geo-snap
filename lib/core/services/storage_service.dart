import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gallery_photo.dart';

class StorageService {
  static const _channel = MethodChannel('geo_snap/media_store');

  Future<String> saveJpeg({
    required Uint8List bytes,
    required String filename,
  }) async {
    final uri = await _channel.invokeMethod<String>('saveImage', {
      'bytes': bytes,
      'filename': filename,
    });
    if (uri == null || uri.isEmpty) {
      throw StateError('Android did not return a saved image URI.');
    }
    return uri;
  }

  Future<List<GalleryPhoto>> listPhotos({String? saveFolder, String? saveFolderUri}) async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listImages', {
      'saveFolder': saveFolder,
      'saveFolderUri': saveFolderUri,
    });
    return (raw ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map(
          (item) => GalleryPhoto(
            uri: item['uri'] as String,
            name: item['name'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              (item['dateMillis'] as num).toInt(),
            ),
          ),
        )
        .toList();
  }

  Future<Uint8List> readBytes(String uri) async {
    final bytes = await _channel.invokeMethod<Uint8List>('readImage', {
      'uri': uri,
    });
    if (bytes == null) {
      throw StateError('Unable to read image.');
    }
    return bytes;
  }

  Future<Uint8List> readThumbnail(String uri, {int width = 250, int height = 250}) async {
    final bytes = await _channel.invokeMethod<Uint8List>('readThumbnail', {
      'uri': uri,
      'width': width,
      'height': height,
    });
    if (bytes == null) {
      return Uint8List(0);
    }
    return bytes;
  }

  Future<void> delete(String uri) async {
    await _channel.invokeMethod<void>('deleteImage', {'uri': uri});
  }

  Future<void> share(GalleryPhoto photo) async {
    final bytes = await readBytes(photo.uri);
    final tempFile = XFile.fromData(
      bytes,
      name: photo.name,
      mimeType: 'image/jpeg',
      lastModified: photo.createdAt,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [tempFile],
        fileNameOverrides: [photo.name],
        subject: 'GeoSnap photo',
        text: photo.name,
        sharePositionOrigin: null,
      ),
    );
  }
}
