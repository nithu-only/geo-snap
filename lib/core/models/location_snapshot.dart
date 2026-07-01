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
  }) {
    return LocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
      capturedAt: capturedAt,
      placeName: placeName,
      city: city,
      state: state,
      country: country,
    );
  }
}
