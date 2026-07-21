class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.capturedAt,
    this.heading = 0.0,
    this.placeName,
    this.city,
    this.state,
    this.country,
    this.postalCode,
    this.countryCode,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final DateTime capturedAt;
  final double heading;
  final String? placeName;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? countryCode;

  String get cardinalDirection {
    final norm = (heading % 360 + 360) % 360;
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((norm + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  String get headingFormatted {
    if (heading < 0) return '';
    return '${heading.round()}° $cardinalDirection';
  }

  String get flagEmoji {
    final code = countryCode?.trim().toUpperCase();
    if (code == null || code.length != 2) return '';
    return code.codeUnits
        .map((u) => String.fromCharCode(u - 65 + 127462))
        .join();
  }

  String get headerAddress {
    final parts = [city ?? placeName, state, country]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    if (parts.isEmpty) {
      final latSign = latitude >= 0 ? 'N' : 'S';
      final lonSign = longitude >= 0 ? 'E' : 'W';
      return 'GPS: ${latitude.abs().toStringAsFixed(5)}° $latSign, ${longitude.abs().toStringAsFixed(5)}° $lonSign';
    }
    final base = parts.join(', ');
    final emoji = flagEmoji;
    return emoji.isNotEmpty ? '$base $emoji' : base;
  }

  String get bodyAddress {
    final parts = [
      if (placeName != null && placeName != city) placeName,
      city,
      state,
      if (postalCode != null) postalCode,
      country,
    ]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    if (parts.isEmpty) {
      return 'Alt: ${altitude.toStringAsFixed(1)}m   Acc: ${accuracy.toStringAsFixed(1)}m';
    }
    return parts.join(', ');
  }

  String get shortAddress {
    final parts = [placeName, state, country]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    if (parts.isEmpty) {
      return 'Lat: ${latitude.toStringAsFixed(5)}  Long: ${longitude.toStringAsFixed(5)}';
    }
    return parts.join(', ');
  }

  String get fullAddress {
    final parts = [placeName, city, state, country]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    if (parts.isEmpty) {
      return 'Lat: ${latitude.toStringAsFixed(5)}, Long: ${longitude.toStringAsFixed(5)} (Alt: ${altitude.toStringAsFixed(1)}m)';
    }
    return parts.join(', ');
  }

  LocationSnapshot copyWithAddress({
    String? placeName,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? countryCode,
    double? heading,
  }) {
    return LocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      capturedAt: capturedAt,
      heading: heading ?? this.heading,
      placeName: placeName ?? this.placeName,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  LocationSnapshot copyWithHeading(double newHeading) {
    return LocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      capturedAt: capturedAt,
      heading: newHeading,
      placeName: placeName,
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
      countryCode: countryCode,
    );
  }
}
