class GalleryPhoto {
  const GalleryPhoto({
    required this.uri,
    required this.name,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  final String uri;
  final String name;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
}
