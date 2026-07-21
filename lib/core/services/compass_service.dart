import 'dart:async';
import 'package:flutter_compass/flutter_compass.dart';

class CompassService {
  StreamSubscription<CompassEvent>? _subscription;
  final StreamController<double> _controller = StreamController<double>.broadcast();
  double? _lastHeading;

  Stream<double> get compassStream => _controller.stream;

  void startListening() {
    _subscription?.cancel();
    _subscription = FlutterCompass.events?.listen((CompassEvent event) {
      final heading = event.heading;
      if (heading != null) {
        final normalized = (heading % 360 + 360) % 360;
        if (_lastHeading == null) {
          _lastHeading = normalized;
        } else {
          // Low-pass filter for smooth UI updates
          double diff = normalized - _lastHeading!;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;
          _lastHeading = (_lastHeading! + diff * 0.35) % 360;
          if (_lastHeading! < 0) _lastHeading = _lastHeading! + 360;
        }
        _controller.add(_lastHeading!);
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    stopListening();
    _controller.close();
  }
}
