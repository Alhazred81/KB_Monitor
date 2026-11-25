import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';

typedef CompassCallback = void Function(double? heading, double? accuracy);

class LocationCompassService {
  LatLng _currentPosition = const LatLng(
    37.422500,
    -122.084500,
  ); // Alapértelmezett pozíció
  String _statusMessage = 'GPS pozíció keresése...';
  double? _heading = 0.0;
  double? _accuracy;
  DateTime _lastCompassUpdate = DateTime.now();
  StreamSubscription<CompassEvent>? _compassSubscription;
  CompassCallback? _primaryCompassListener;
  final List<CompassCallback> _extraCompassListeners = [];
  Future<LatLng?>? _pendingPositionFuture;

  LatLng get currentPosition => _currentPosition;
  String get statusMessage => _statusMessage;
  double? get heading => _heading;
  double? get accuracy => _accuracy;

  // GPS pozíció frissítése (párhuzamos hívások összevonásával)
  Future<LatLng?> updatePosition() {
    if (_pendingPositionFuture != null) {
      return _pendingPositionFuture!;
    }
    final fut = _performUpdatePosition();
    _pendingPositionFuture = fut;
    fut.whenComplete(() {
      if (identical(_pendingPositionFuture, fut)) {
        _pendingPositionFuture = null;
      }
    });
    return fut;
  }

  Future<LatLng?> _performUpdatePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _statusMessage = 'A helymeghatározás ki van kapcsolva.';
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _statusMessage = 'Helymeghatározási engedély megtagadva.';
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _statusMessage = 'Helymeghatározási engedély véglegesen letiltva.';
      return null;
    }

    try {
      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
        _statusMessage =
            '${lastKnown.latitude.toStringAsFixed(5)}, ${lastKnown.longitude.toStringAsFixed(5)}';
      }
      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _statusMessage =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      return _currentPosition;
    } catch (e) {
      if (_statusMessage == 'GPS pozíció keresése...') {
        _statusMessage = 'GPS hiba: $e';
      }
      return _currentPosition;
    }
  }

  // Fő iránytű figyelő regisztrálása (térkép) – nem törli az ideiglenes al-figyelőket
  void initCompass(CompassCallback onUpdate) {
    _primaryCompassListener = onUpdate;
    _ensureCompassStreamStarted();
  }

  // Kiegészítő iránytű figyelő hozzáadása (pl. Új kaptár varázsló 3. lépés) a fő figyelő felülírása nélkül
  void addCompassListener(CompassCallback listener) {
    if (!_extraCompassListeners.contains(listener)) {
      _extraCompassListeners.add(listener);
    }
    _ensureCompassStreamStarted();
  }

  void removeCompassListener(CompassCallback listener) {
    _extraCompassListeners.remove(listener);
  }

  void _ensureCompassStreamStarted() {
    if (_compassSubscription != null) return;
    _compassSubscription = FlutterCompass.events?.listen(
      (CompassEvent event) {
        final double? rawHeading = event.heading;
        if (rawHeading == null || rawHeading.isNaN) return;

        final now = DateTime.now();
        if (now.difference(_lastCompassUpdate).inMilliseconds < 300) {
          return;
        }
        double diff = _heading == null ? 360.0 : (rawHeading - _heading!).abs();
        if (diff > 180.0) diff = 360.0 - diff;

        if (diff >= 2.0) {
          _lastCompassUpdate = now;
          _heading = rawHeading;
          _accuracy = event.accuracy;
          _primaryCompassListener?.call(_heading, _accuracy);
          if (_extraCompassListeners.isNotEmpty) {
            for (final l in List<CompassCallback>.from(_extraCompassListeners)) {
              l(_heading, _accuracy);
            }
          }
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void pauseCompass() {
    if (_compassSubscription != null && !_compassSubscription!.isPaused) {
      _compassSubscription!.pause();
    }
  }

  void resumeCompass() {
    if (_compassSubscription != null && _compassSubscription!.isPaused) {
      _compassSubscription!.resume();
    }
  }

  void dispose() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    _primaryCompassListener = null;
    _extraCompassListeners.clear();
  }

  String getHeadingText(double? heading) {
    if (heading == null || heading.isNaN) return '---°';
    int h = ((heading.round() % 360) + 360) % 360;
    if (h >= 338 || h < 23) return 'É ($h°)';
    if (h >= 23 && h < 68) return 'ÉK ($h°)';
    if (h >= 68 && h < 113) return 'K ($h°)';
    if (h >= 113 && h < 158) return 'DK ($h°)';
    if (h >= 158 && h < 203) return 'D ($h°)';
    if (h >= 203 && h < 248) return 'DNY ($h°)';
    if (h >= 248 && h < 293) return 'NY ($h°)';
    return 'ÉNY ($h°)';
  }
}
