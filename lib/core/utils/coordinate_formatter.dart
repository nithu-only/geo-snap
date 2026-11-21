import 'dart:math' as math;

enum CoordinateFormat { decimal, dms, utm }

class CoordinateFormatter {
  static String format({
    required double latitude,
    required double longitude,
    required CoordinateFormat format,
  }) {
    switch (format) {
      case CoordinateFormat.dms:
        return toDms(latitude, longitude);
      case CoordinateFormat.utm:
        return toUtm(latitude, longitude);
      case CoordinateFormat.decimal:
        return toDecimal(latitude, longitude);
    }
  }

  static String toDecimal(double latitude, double longitude) {
    return 'Lat ${latitude.toStringAsFixed(6)}° Long ${longitude.toStringAsFixed(6)}°';
  }

  static String toDms(double latitude, double longitude) {
    final latDms = _formatSingleDms(latitude, isLatitude: true);
    final lonDms = _formatSingleDms(longitude, isLatitude: false);
    return '$latDms  $lonDms';
  }

  static String _formatSingleDms(double val, {required bool isLatitude}) {
    final absVal = val.abs();
    final deg = absVal.floor();
    final minRemainder = (absVal - deg) * 60.0;
    final min = minRemainder.floor();
    final sec = (minRemainder - min) * 60.0;
    final dir = isLatitude
        ? (val >= 0 ? 'N' : 'S')
        : (val >= 0 ? 'E' : 'W');
    return "$deg° ${min.toString().padLeft(2, '0')}' ${sec.toStringAsFixed(2)}\" $dir";
  }

  /// Converts Latitude/Longitude to Universal Transverse Mercator (UTM) coordinates.
  /// Uses the WGS84 standard ellipsoid.
  static String toUtm(double latitude, double longitude) {
    if (latitude < -80.0 || latitude > 84.0) {
      // Outside standard UTM coverage; fallback to DMS
      return toDms(latitude, longitude);
    }

    const a = 6378137.0; // WGS84 semi-major axis
    const f = 1.0 / 298.257223563; // Flattening
    const k0 = 0.9996; // Scale factor

    final e2 = 2 * f - f * f;
    final ePrime2 = e2 / (1.0 - e2);

    final zone = ((longitude + 180.0) / 6.0).floor() + 1;
    final zoneClamped = zone.clamp(1, 60);
    final centralMeridianDeg = (zoneClamped - 1) * 6 - 180 + 3;

    final latRad = latitude * math.pi / 180.0;
    final lonRad = longitude * math.pi / 180.0;
    final centralMeridianRad = centralMeridianDeg * math.pi / 180.0;
    final deltaLon = lonRad - centralMeridianRad;

    final sinLat = math.sin(latRad);
    final cosLat = math.cos(latRad);
    final tanLat = math.tan(latRad);

    final n = a / math.sqrt(1.0 - e2 * sinLat * sinLat);
    final t = tanLat * tanLat;
    final c = ePrime2 * cosLat * cosLat;
    final aTerm = cosLat * deltaLon;

    // Meridional arc M
    final m = a *
        ((1.0 - e2 / 4.0 - 3.0 * e2 * e2 / 64.0 - 5.0 * e2 * e2 * e2 / 256.0) * latRad -
            (3.0 * e2 / 8.0 + 3.0 * e2 * e2 / 32.0 + 45.0 * e2 * e2 * e2 / 1024.0) * math.sin(2.0 * latRad) +
            (15.0 * e2 * e2 / 256.0 + 45.0 * e2 * e2 * e2 / 1024.0) * math.sin(4.0 * latRad) -
            (35.0 * e2 * e2 * e2 / 3072.0) * math.sin(6.0 * latRad));

    final easting = 500000.0 +
        k0 *
            n *
            (aTerm +
                (1.0 - t + c) * math.pow(aTerm, 3) / 6.0 +
                (5.0 - 18.0 * t + t * t + 72.0 * c - 58.0 * ePrime2) * math.pow(aTerm, 5) / 120.0);

    var northing = k0 *
        (m +
            n *
                tanLat *
                (math.pow(aTerm, 2) / 2.0 +
                    (5.0 - t + 9.0 * c + 4.0 * c * c) * math.pow(aTerm, 4) / 24.0 +
                    (61.0 - 58.0 * t + t * t + 600.0 * c - 330.0 * ePrime2) * math.pow(aTerm, 6) / 720.0));

    if (latitude < 0) {
      northing += 10000000.0; // Southern hemisphere false northing
    }

    final letterIndex = ((latitude + 80.0) / 8.0).floor().clamp(0, 19);
    const utmLetters = 'CDEFGHJKLMNPQRSTUVWX';
    final bandLetter = utmLetters[letterIndex];

    return '$zoneClamped$bandLetter ${easting.round()}m E  ${northing.round()}m N';
  }
}
