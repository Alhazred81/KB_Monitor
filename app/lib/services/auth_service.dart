import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticateUser() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        return true; // Ha nincs biometrikus támogatás, engedjük át vagy kezeljük logikusan
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason:
            'Kérlek azonosítsd magad a méhészet biztonságos eléréséhez',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Hitelesítési hiba: $e');
      return false;
    }
  }
}
