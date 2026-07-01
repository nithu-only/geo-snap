import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/core/models/location_snapshot.dart';

void main() {
  test('builds readable address from available parts', () {
    final snapshot = LocationSnapshot(
      latitude: 13.022751,
      longitude: 74.793574,
      accuracy: 8,
      altitude: 4,
      capturedAt: DateTime(2026, 6, 3, 14, 26),
      placeName: 'Sasihithlu',
      state: 'Karnataka',
      country: 'India',
    );

    expect(snapshot.shortAddress, 'Sasihithlu, Karnataka, India');
  });
}
