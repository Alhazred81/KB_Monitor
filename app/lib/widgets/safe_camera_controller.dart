import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Biztonságos MobileScannerController kiegészítés boxkesztyűbarát és külső USB kamerákhoz
extension SafeMobileScannerController on MobileScannerController {
  /// Biztonságos kamera váltás - ha nincs inicializálva, NEM dob kivételt, hanem elindítja a kamerát!
  Future<void> safeSwitchCamera() async {
    try {
      // 1. Ha még nincs inicializálva, a start()-ot hívjuk meg switchCamera() helyett (utóbbi kivételt dobna)
      if (!value.isInitialized) {
        await start();
        return;
      }

      // 2. Váltás előlapi és hátlapi kamera között
      if (value.cameraDirection == CameraFacing.front) {
        await stop();
        await start(cameraDirection: CameraFacing.back);
      } else if (value.cameraDirection == CameraFacing.back) {
        await stop();
        await start(cameraDirection: CameraFacing.front);
      } else {
        // Unknown / External USB kamera esetén
        try {
          await switchCamera();
        } catch (_) {
          await stop();
          await start();
        }
      }
    } catch (e) {
      debugPrint('Kamera váltás hiba: $e');
      try {
        await start();
      } catch (_) {}
    }
  }

  /// Biztonságos vaku kapcsolás
  Future<void> safeToggleTorch() async {
    try {
      if (value.isInitialized) {
        await toggleTorch();
      }
    } catch (e) {
      debugPrint('Vaku hiba: $e');
    }
  }
}
