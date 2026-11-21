import 'package:flutter_test/flutter_test.dart';
import 'package:geo_snap/core/utils/coordinate_formatter.dart';

void main() {
  group('CoordinateFormatter tests', () {
    test('formats Decimal correctly', () {
      final res = CoordinateFormatter.format(
        latitude: 12.971598,
        longitude: 77.594562,
        format: CoordinateFormat.decimal,
      );
      expect(res, 'Lat 12.971598° Long 77.594562°');
    });

    test('formats DMS correctly', () {
      final res = CoordinateFormatter.format(
        latitude: 12.971598,
        longitude: 77.594562,
        format: CoordinateFormat.dms,
      );
      expect(res.contains('12° 58\''), isTrue);
      expect(res.contains('N'), isTrue);
      expect(res.contains('77° 35\''), isTrue);
      expect(res.contains('E'), isTrue);
    });

    test('formats UTM correctly', () {
      final res = CoordinateFormatter.format(
        latitude: 12.971598,
        longitude: 77.594562,
        format: CoordinateFormat.utm,
      );
      expect(res.contains('43P'), isTrue);
      expect(res.contains('m E'), isTrue);
      expect(res.contains('m N'), isTrue);
    });
  });
}
