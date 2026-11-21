import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class MapThumbnailService {
  Future<Uint8List?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    // 1. Try ArcGIS Satellite Imagery (Primary)
    final arcGisBytes = await _fetchArcGis(latitude, longitude);
    if (arcGisBytes != null) {
      return arcGisBytes;
    }

    // 2. Fallback to CartoDB Voyager CDN Tile (Fast Secondary)
    final cartoBytes = await _fetchCartoDb(latitude, longitude);
    if (cartoBytes != null) {
      return cartoBytes;
    }

    return null;
  }

  Future<Uint8List?> _fetchArcGis(double latitude, double longitude) async {
    final double delta = 0.0018;
    final xmin = longitude - delta;
    final ymin = latitude - delta;
    final xmax = longitude + delta;
    final ymax = latitude + delta;

    final uri = Uri.https(
      'services.arcgisonline.com',
      '/ArcGIS/rest/services/World_Imagery/MapServer/export',
      {
        'bbox': '$xmin,$ymin,$xmax,$ymax',
        'bboxSR': '4326',
        'size': '300,300',
        'imageSR': '4326',
        'format': 'png',
        'f': 'image',
      },
    );

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'GeoSnap/1.4 (Android; GPS Camera)',
      }).timeout(AppConstants.mapTimeout);
      if (response.statusCode == 200 &&
          response.headers['content-type']?.startsWith('image/') == true &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<Uint8List?> _fetchCartoDb(double latitude, double longitude) async {
    try {
      const zoom = 15;
      final x = ((longitude + 180.0) / 360.0 * (1 << zoom)).floor();
      final latRad = latitude * math.pi / 180.0;
      final y = ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * (1 << zoom)).floor();

      final uri = Uri.https('basemaps.cartocdn.com', '/rastertiles/voyager/$zoom/$x/$y.png');
      final response = await http.get(uri, headers: {
        'User-Agent': 'GeoSnap/1.4 (Android; GPS Camera)',
      }).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 &&
          response.headers['content-type']?.startsWith('image/') == true &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }
}
