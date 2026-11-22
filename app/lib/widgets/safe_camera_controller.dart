import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Biztonságos MobileScannerController kiegészítés boxkesztyűbarát és külső USB kamerákhoz
extension SafeMobileScannerController on MobileScannerController {
  /// Biztonságos kamera váltás - ha nincs inicializálva vagy már indul, NEM dob kivételt!
  Future<void> safeSwitchCamera() async {
    try {
      // 1. Ha már éppen indul a kamera, ne indítsuk újra párhuzamosan
      if (value.isStarting) {
        return;
      }

      // 2. Ha még nincs inicializálva vagy le van állítva, indítsuk el
      if (!value.isInitialized || !value.isRunning) {
        await start();
        return;
      }

      // 3. Ha 1 vagy kevesebb kamera érhető el, nincs hova váltani
      if (value.availableCameras != null && value.availableCameras! < 2) {
        return;
      }

      // 4. Váltás előlapi és hátlapi kamera között
      if (value.cameraDirection == CameraFacing.front) {
        await stop();
        await start(cameraDirection: CameraFacing.back);
      } else if (value.cameraDirection == CameraFacing.back) {
        await stop();
        await start(cameraDirection: CameraFacing.front);
      } else {
        // Unknown / External USB kamera esetén biztonságos újraindítás
        try {
          await stop();
          await start();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Kamera váltás hiba: $e');
    }
  }

  /// Biztonságos vaku kapcsolás - csak futó és inicializált kameránál hívható
  Future<void> safeToggleTorch() async {
    try {
      if (value.isInitialized && value.isRunning && !value.isStarting) {
        await toggleTorch();
      }
    } catch (e) {
      debugPrint('Vaku hiba: $e');
    }
  }
}
