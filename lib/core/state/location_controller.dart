import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_constants.dart';
import '../models/location_snapshot.dart';
import '../services/location_service.dart';
import '../services/map_thumbnail_service.dart';
import '../services/native_location_service.dart';

class LocationController extends ChangeNotifier {
  LocationController(
    this._service,
    this._nativeLocationService,
    this._mapThumbnailService,
  );

  final LocationService _service;
  final NativeLocationService _nativeLocationService;
  final MapThumbnailService _mapThumbnailService;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  LocationSnapshot? _snapshot;
  bool _permissionGranted = false;
  bool _loading = false;
  String? _message;
  LocationSnapshot? _cachedEnrichment;
  DateTime? _lastEnrichmentAt;
  Uint8List? _cachedMapBytes;
  bool _refreshingEnrichment = false;

  LocationSnapshot? get snapshot => _snapshot;
  bool get permissionGranted => _permissionGranted;
  bool get loading => _loading;
  String? get message => _message;
  Uint8List? get cachedMapBytes => _cachedMapBytes;

  bool get hasCaptureAccuracy =>
      _snapshot != null &&
      _snapshot!.accuracy <= AppConstants.targetAccuracyMeters;

  Future<void> start() async {
    _loading = true;
    _message = 'Checking location permission';
    notifyListeners();

    _permissionGranted = await _service.ensurePermission();
    if (!_permissionGranted) {
      _loading = false;
      _message = 'Location permission or GPS is unavailable';
      notifyListeners();
      return;
    }

    await _subscription?.cancel();
    _subscription = _nativeLocationService.positionStream().listen(
      (position) {
        final latitude = (position['latitude'] as num).toDouble();
        final longitude = (position['longitude'] as num).toDouble();
        final cached = _cachedEnrichment;
        _snapshot = LocationSnapshot(
          latitude: latitude,
          longitude: longitude,
          accuracy: (position['accuracy'] as num).toDouble(),
          altitude: (position['altitude'] as num?)?.toDouble() ?? 0,
          capturedAt: DateTime.now(),
          placeName: cached?.placeName,
          city: cached?.city,
          state: cached?.state,
          country: cached?.country,
          postalCode: cached?.postalCode,
          countryCode: cached?.countryCode,
        );
        _loading = false;
        _message = hasCaptureAccuracy
            ? 'GPS ready'
            : 'Waiting for accuracy below ${AppConstants.targetAccuracyMeters.toStringAsFixed(0)}m';
        notifyListeners();
        _refreshEnrichmentIfNeeded(_snapshot!);
      },
      onError: (_) {
        _loading = false;
        _message = 'Unable to read GPS location';
        notifyListeners();
      },
    );
  }

  Future<void> warmUp() async {
    await start();
  }

  LocationSnapshot? captureSnapshot() => _snapshot;

  Future<void> _refreshEnrichmentIfNeeded(LocationSnapshot current) async {
    if (_refreshingEnrichment) {
      return;
    }
    final previous = _cachedEnrichment;
    final elapsed = _lastEnrichmentAt == null
        ? const Duration(days: 1)
        : DateTime.now().difference(_lastEnrichmentAt!);
    final distance = previous == null
        ? double.infinity
        : Geolocator.distanceBetween(
            previous.latitude,
            previous.longitude,
            current.latitude,
            current.longitude,
          );
    if (distance < 100 && elapsed < const Duration(minutes: 5)) {
      return;
    }

    _refreshingEnrichment = true;
    try {
      final results = await Future.wait<Object?>([
        _service.resolveAddress(current),
        _mapThumbnailService.fetch(
          latitude: current.latitude,
          longitude: current.longitude,
        ),
      ]);
      _cachedEnrichment = results[0] as LocationSnapshot;
      _cachedMapBytes = results[1] as Uint8List?;
      _lastEnrichmentAt = DateTime.now();
      final latest = _snapshot;
      if (latest != null) {
        _snapshot = latest.copyWithAddress(
          placeName: _cachedEnrichment?.placeName,
          city: _cachedEnrichment?.city,
          state: _cachedEnrichment?.state,
          country: _cachedEnrichment?.country,
        );
        notifyListeners();
      }
    } finally {
      _refreshingEnrichment = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
