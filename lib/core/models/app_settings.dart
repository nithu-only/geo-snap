enum WatermarkTemplate { compact, largePanel, gpsMapCamera }

enum WatermarkPosition { topLeft, topRight, bottomLeft, bottomRight }

class AppSettings {
  const AppSettings({
    required this.template,
    required this.position,
    required this.timestampPattern,
    required this.showAddress,
    required this.showCoordinates,
    required this.showAccuracy,
    required this.showMapPreview,
  });

  factory AppSettings.defaults() => const AppSettings(
    template: WatermarkTemplate.gpsMapCamera,
    position: WatermarkPosition.bottomLeft,
    timestampPattern: 'dd-MMM-yyyy hh:mm a',
    showAddress: true,
    showCoordinates: true,
    showAccuracy: true,
    showMapPreview: true,
  );

  final WatermarkTemplate template;
  final WatermarkPosition position;
  final String timestampPattern;
  final bool showAddress;
  final bool showCoordinates;
  final bool showAccuracy;
  final bool showMapPreview;

  AppSettings copyWith({
    WatermarkTemplate? template,
    WatermarkPosition? position,
    String? timestampPattern,
    bool? showAddress,
    bool? showCoordinates,
    bool? showAccuracy,
    bool? showMapPreview,
  }) {
    return AppSettings(
      template: template ?? this.template,
      position: position ?? this.position,
      timestampPattern: timestampPattern ?? this.timestampPattern,
      showAddress: showAddress ?? this.showAddress,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showAccuracy: showAccuracy ?? this.showAccuracy,
      showMapPreview: showMapPreview ?? this.showMapPreview,
    );
  }
}
