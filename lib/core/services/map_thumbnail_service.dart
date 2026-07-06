import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class MapThumbnailService {
  Future<Uint8List?> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return null;
    }

    final double delta = 0.0018;
    final xmin = longitude - delta;
    final ymin = latitude - delta;
    final xmax = longitude + delta;
    final ymax = latitude + delta;

    final uri = Uri.https('services.arcgisonline.com', '/ArcGIS/rest/services/World_Imagery/MapServer/export', {
      'bbox': '$xmin,$ymin,$xmax,$ymax',
      'bboxSR': '4326',
      'size': '300,300',
      'imageSR': '4326',
      'format': 'png',
      'f': 'image',
    });

    try {
      final response = await http.get(uri, headers: {
        'User-Agent': 'GeoSnap/1.0 (Android; Offline GPS Camera)',
      }).timeout(AppConstants.mapTimeout);
      if (response.statusCode == 200 &&
          response.headers['content-type']?.startsWith('image/') == true) {
        return response.bodyBytes;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
