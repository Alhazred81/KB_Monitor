import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Némítást felülíró vészjelző hang- és rezgésszolgáltatás.
/// Androidon natív `AudioManager.STREAM_ALARM` csatornát használ (amely néma/rezgő módban is
/// maximális hangerővel szólal meg a „LEOKÉZOM” gomb megnyomásáig), asztali (Windows) környezetben
/// vagy Hot Reload alatt pedig automatikusan visszalép a folyamatos rendszer-riasztóhang + rezgés ciklusra.
class AlarmSoundService {
  AlarmSoundService._();
  static final AlarmSoundService instance = AlarmSoundService._();

  static const MethodChannel _channel = MethodChannel('hive_monitor/alarm');

  Timer? _fallbackBeepTimer;
  bool _isSirenActive = false;
  bool get isSirenActive => _isSirenActive;

  Future<void> startContinuousSiren() async {
    _isSirenActive = true;
    _fallbackBeepTimer?.cancel();
    _fallbackBeepTimer = null;

    bool nativeHandled = false;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('startAlarm');
        nativeHandled = true;
      } catch (e) {
        debugPrint('Natív alarm csatorna fallback aktiválva: $e');
      }
    }

    if (!nativeHandled) {
      _pulseFallbackOnce();
      _fallbackBeepTimer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) {
          if (!_isSirenActive) {
            _fallbackBeepTimer?.cancel();
            _fallbackBeepTimer = null;
            return;
          }
          _pulseFallbackOnce();
        },
      );
    }
  }

  void _pulseFallbackOnce() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  Future<void> stopSiren() async {
    _isSirenActive = false;
    _fallbackBeepTimer?.cancel();
    _fallbackBeepTimer = null;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('stopAlarm');
      } catch (_) {}
    }
  }

  Future<void> playSingleAlertBeep() async {
    bool nativeHandled = false;
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('playOnce');
        nativeHandled = true;
      } catch (_) {}
    }
    if (!nativeHandled) {
      try {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }
}
