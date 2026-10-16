import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_compass/flutter_compass.dart';

class LocationCompassService {
  LatLng _currentPosition = const LatLng(
    37.422500,
    -122.084500,
  ); // Alapértelmezett Google HQ
  String _statusMessage = 'GPS pozíció keresése...';
  double? _heading = 0.0;
  double? _accuracy;
  DateTime _lastCompassUpdate = DateTime.now();

  LatLng get currentPosition => _currentPosition;
  String get statusMessage => _statusMessage;
  double? get heading => _heading;
  double? get accuracy => _accuracy;

  // GPS pozíció frissítése
  Future<LatLng?> updatePosition() async {
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

    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _statusMessage =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      return _currentPosition;
    } catch (e) {
      _statusMessage = 'GPS hiba: $e';
      return null;
    }
  }

  // Iránytű események indítása (ritkítva a ventilátor-hatás elkerüléséért)
  void initCompass(Function(double? heading, double? accuracy) onUpdate) {
    FlutterCompass.events?.listen((CompassEvent event) {
      if (event.heading != null) {
        final now = DateTime.now();
        if (now.difference(_lastCompassUpdate).inMilliseconds > 400 ||
            (_heading != null && (event.heading! - _heading!).abs() > 2.0)) {
          _lastCompassUpdate = now;
          _heading = event.heading;
          _accuracy = event.accuracy;
          onUpdate(_heading, _accuracy);
        }
      }
    });
  }

  String getHeadingText(double? heading) {
    if (heading == null) return '---°';
    int h = heading.round();
    if (h >= 337.5 || h < 22.5) return 'É ($h°)';
    if (h >= 22.5 && h < 67.5) return 'ÉÉK ($h°)';
    if (h >= 67.5 && h < 112.5) return 'K ($h°)';
    if (h >= 112.5 && h < 157.5) return 'DDK ($h°)';
    if (h >= 157.5 && h < 202.5) return 'D ($h°)';
    if (h >= 202.5 && h < 247.5) return 'DDNY ($h°)';
    if (h >= 247.5 && h < 292.5) return 'NY ($h°)';
    if (h >= 292.5 && h < 337.5) return 'ÉNY ($h°)';
    return '$h°';
  }
}
