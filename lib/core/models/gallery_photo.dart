class GalleryPhoto {
  const GalleryPhoto({
    required this.uri,
    required this.name,
    required this.createdAt,
  });

  final String uri;
  final String name;
  final DateTime createdAt;
}
