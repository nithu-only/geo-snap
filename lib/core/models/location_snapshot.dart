class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.capturedAt,
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
  final String? placeName;
  final String? city;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? countryCode;

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
    final base = parts.isEmpty ? 'Location unavailable' : parts.join(', ');
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
    return parts.isEmpty ? 'Location unavailable' : parts.join(', ');
  }

  String get shortAddress {
    final parts = [placeName, state, country]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? 'Location unavailable' : parts.join(', ');
  }

  String get fullAddress {
    final parts = [placeName, city, state, country]
        .where((part) => part != null && part.trim().isNotEmpty)
        .cast<String>()
        .toList();
    return parts.isEmpty ? shortAddress : parts.join(', ');
  }

  LocationSnapshot copyWithAddress({
    String? placeName,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? countryCode,
  }) {
    return LocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      capturedAt: capturedAt,
      placeName: placeName ?? this.placeName,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      countryCode: countryCode ?? this.countryCode,
    );
  }
}
