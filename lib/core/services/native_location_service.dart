import 'package:flutter/services.dart';

class NativeLocationService {
  static const _events = EventChannel('geotag_camera/location_events');

  Stream<Map<String, dynamic>> positionStream() {
    return _events.receiveBroadcastStream().map(
      (event) => Map<String, dynamic>.from(event as Map),
    );
  }
}
