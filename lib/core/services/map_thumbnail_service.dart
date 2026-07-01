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

    final uri = Uri.https('staticmap.openstreetmap.de', '/staticmap.php', {
      'center': '$latitude,$longitude',
      'zoom': '16',
      'size': '360x180',
      'markers': '$latitude,$longitude,red-pushpin',
    });

    try {
      final response = await http.get(uri).timeout(AppConstants.mapTimeout);
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
