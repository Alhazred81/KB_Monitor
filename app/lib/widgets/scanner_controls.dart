import 'package:flutter/material.dart';

class ScannerControls extends StatelessWidget {
  final TextEditingController? idController;
  final bool isNfcScanning;
  final Animation<Color?> nfcColorAnim;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onCameraPressed;
  final VoidCallback onNfcPressed;
  final VoidCallback onNfcStop;

  const ScannerControls({
    super.key,
    this.idController,
    required this.isNfcScanning,
    required this.nfcColorAnim,
    this.onSubmitted,
    required this.onCameraPressed,
    required this.onNfcPressed,
    required this.onNfcStop,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 120,
              child: ElevatedButton(
                onPressed: onCameraPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xBF000000),
                  foregroundColor: Colors.amberAccent,
                  side: const BorderSide(color: Colors.amber, width: 3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, size: 50),
                    SizedBox(height: 6),
                    Text(
                      'KAMERA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 120,
              child: AnimatedBuilder(
                animation: nfcColorAnim,
                builder: (context, child) {
                  Color activeColor = nfcColorAnim.value ?? Colors.white;
                  return ElevatedButton(
                    onPressed: isNfcScanning ? onNfcStop : onNfcPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNfcScanning
                          ? Colors.black
                          : const Color(0xBF000000),
                      foregroundColor: isNfcScanning
                          ? activeColor
                          : Colors.amberAccent,
                      side: BorderSide(
                        color: isNfcScanning ? activeColor : Colors.amber,
                        width: isNfcScanning ? 6 : 3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.nfc,
                          size: 50,
                          color: isNfcScanning
                              ? activeColor
                              : Colors.amberAccent,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isNfcScanning ? 'OLVASÁS...' : 'NFC',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: isNfcScanning
                                ? activeColor
                                : Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
