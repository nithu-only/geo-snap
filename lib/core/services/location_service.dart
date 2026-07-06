import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../models/location_snapshot.dart';

class LocationService {
  Stream<Position> positionStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
    return Geolocator.getPositionStream(locationSettings: settings);
  }

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LocationSnapshot?> currentSnapshot() async {
    if (!await ensurePermission()) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      altitude: position.altitude,
      capturedAt: DateTime.now(),
    );
  }

  Future<LocationSnapshot> resolveAddress(LocationSnapshot snapshot) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        snapshot.latitude,
        snapshot.longitude,
      ).timeout(const Duration(seconds: 5));
      if (placemarks.isEmpty) {
        return snapshot;
      }
      final place = placemarks.first;
      return snapshot.copyWithAddress(
        placeName: _firstNonBlank([
          place.subLocality,
          place.locality,
          place.street,
          place.name,
        ]),
        city: _firstNonBlank([place.locality, place.subAdministrativeArea]),
        state: place.administrativeArea,
        country: place.country,
        postalCode: place.postalCode,
        countryCode: place.isoCountryCode,
      );
    } catch (_) {
      return snapshot;
    }
  }

  Future<bool> ensureCameraPermission() async {
    final status = await permissions.Permission.camera.request();
    return status.isGranted;
  }

  String? _firstNonBlank(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
