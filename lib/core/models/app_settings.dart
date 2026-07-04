enum WatermarkTemplate { compact, largePanel, gpsMapCamera }

enum WatermarkPosition { topLeft, topRight, bottomLeft, bottomRight }

enum FlashMode { off, on, auto }

enum CameraLens { back, front }

class AppSettings {
  const AppSettings({
    required this.template,
    required this.position,
    required this.timestampPattern,
    required this.showAddress,
    required this.showCoordinates,
    required this.showAccuracy,
    required this.showMapPreview,
    required this.flashMode,
    required this.cameraLens,
    required this.showGrid,
  });

  factory AppSettings.defaults() => const AppSettings(
    template: WatermarkTemplate.gpsMapCamera,
    position: WatermarkPosition.bottomLeft,
    timestampPattern: 'dd-MMM-yyyy hh:mm a',
    showAddress: true,
    showCoordinates: true,
    showAccuracy: true,
    showMapPreview: true,
    flashMode: FlashMode.off,
    cameraLens: CameraLens.back,
    showGrid: false,
  );

  final WatermarkTemplate template;
  final WatermarkPosition position;
  final String timestampPattern;
  final bool showAddress;
  final bool showCoordinates;
  final bool showAccuracy;
  final bool showMapPreview;
  final FlashMode flashMode;
  final CameraLens cameraLens;
  final bool showGrid;

  AppSettings copyWith({
    WatermarkTemplate? template,
    WatermarkPosition? position,
    String? timestampPattern,
    bool? showAddress,
    bool? showCoordinates,
    bool? showAccuracy,
    bool? showMapPreview,
    FlashMode? flashMode,
    CameraLens? cameraLens,
    bool? showGrid,
  }) {
    return AppSettings(
      template: template ?? this.template,
      position: position ?? this.position,
      timestampPattern: timestampPattern ?? this.timestampPattern,
      showAddress: showAddress ?? this.showAddress,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showAccuracy: showAccuracy ?? this.showAccuracy,
      showMapPreview: showMapPreview ?? this.showMapPreview,
      flashMode: flashMode ?? this.flashMode,
      cameraLens: cameraLens ?? this.cameraLens,
      showGrid: showGrid ?? this.showGrid,
    );
  }
}

