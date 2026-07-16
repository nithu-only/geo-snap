enum WatermarkTemplate { compact, largePanel, gpsMapCamera, minimal }

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
    required this.showAltitude,
    required this.showTimestamp,
    required this.flashMode,
    required this.cameraLens,
    required this.showGrid,
    required this.customNote,
    required this.timerSeconds,
    required this.saveFolder,
    required this.saveFolderUri,
    required this.saveFolderLabel,
  });

  factory AppSettings.defaults() => const AppSettings(
    template: WatermarkTemplate.gpsMapCamera,
    position: WatermarkPosition.bottomLeft,
    timestampPattern: 'dd-MMM-yyyy hh:mm a',
    showAddress: true,
    showCoordinates: true,
    showAccuracy: true,
    showMapPreview: true,
    showAltitude: true,
    showTimestamp: true,
    flashMode: FlashMode.off,
    cameraLens: CameraLens.back,
    showGrid: false,
    customNote: '',
    timerSeconds: 0,
    saveFolder: '',
    saveFolderUri: '',
    saveFolderLabel: '',
  );

  final WatermarkTemplate template;
  final WatermarkPosition position;
  final String timestampPattern;
  final bool showAddress;
  final bool showCoordinates;
  final bool showAccuracy;
  final bool showMapPreview;
  final bool showAltitude;
  final bool showTimestamp;
  final FlashMode flashMode;
  final CameraLens cameraLens;
  final bool showGrid;
  final String customNote;
  final int timerSeconds;
  final String saveFolder;
  final String saveFolderUri;
  final String saveFolderLabel;

  AppSettings copyWith({
    WatermarkTemplate? template,
    WatermarkPosition? position,
    String? timestampPattern,
    bool? showAddress,
    bool? showCoordinates,
    bool? showAccuracy,
    bool? showMapPreview,
    bool? showAltitude,
    bool? showTimestamp,
    FlashMode? flashMode,
    CameraLens? cameraLens,
    bool? showGrid,
    String? customNote,
    int? timerSeconds,
    String? saveFolder,
    String? saveFolderUri,
    String? saveFolderLabel,
  }) {
    return AppSettings(
      template: template ?? this.template,
      position: position ?? this.position,
      timestampPattern: timestampPattern ?? this.timestampPattern,
      showAddress: showAddress ?? this.showAddress,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showAccuracy: showAccuracy ?? this.showAccuracy,
      showMapPreview: showMapPreview ?? this.showMapPreview,
      showAltitude: showAltitude ?? this.showAltitude,
      showTimestamp: showTimestamp ?? this.showTimestamp,
      flashMode: flashMode ?? this.flashMode,
      cameraLens: cameraLens ?? this.cameraLens,
      showGrid: showGrid ?? this.showGrid,
      customNote: customNote ?? this.customNote,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      saveFolder: saveFolder ?? this.saveFolder,
      saveFolderUri: saveFolderUri ?? this.saveFolderUri,
      saveFolderLabel: saveFolderLabel ?? this.saveFolderLabel,
    );
  }
}

