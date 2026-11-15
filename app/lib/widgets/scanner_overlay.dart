import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'safe_camera_controller.dart';
export 'safe_camera_controller.dart';

class ScannerOverlay extends StatefulWidget {
  final MobileScannerController cameraController;
  final Function(String code) onDetect;
  final VoidCallback onClose;

  const ScannerOverlay({
    super.key,
    required this.cameraController,
    required this.onDetect,
    required this.onClose,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> {
  bool _isTorchOn = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: widget.cameraController,
          errorBuilder: (context, error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, color: Colors.amberAccent, size: 52),
                  const SizedBox(height: 12),
                  const Text(
                    'Nem érhető el a kamerakép',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hiba: ${error.errorCode}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(180, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.cameraswitch, size: 24),
                    label: const Text('Kamera váltása', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => widget.cameraController.safeSwitchCamera(),
                  ),
                ],
              ),
            );
          },
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                widget.onDetect(barcode.rawValue!);
                break;
              }
            }
          },
        ),
        // Sötétítő maszk a kereső köré
        Container(
          decoration: BoxDecoration(color: Colors.black.withAlpha(100)),
        ),
        // Vezérlőgombok a tetején (Vaku + Boxkesztyűbarát Kamera váltás + Bezárás)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Vaku (Zseblámpa) kapcsoló
                IconButton(
                  onPressed: () async {
                    await widget.cameraController.toggleTorch();
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                  },
                  icon: Icon(
                    _isTorchOn ? Icons.flash_on : Icons.flash_off,
                    color: _isTorchOn ? Colors.amberAccent : Colors.white,
                    size: 30,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.all(12),
                  ),
                ),

                // BOXKESZTYŰBARÁT KAMERA VÁLTÁS GOMB
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.amberAccent,
                    side: const BorderSide(color: Colors.amberAccent, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    minimumSize: const Size(150, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 6,
                  ),
                  onPressed: () => widget.cameraController.safeSwitchCamera(),
                  icon: const Icon(Icons.cameraswitch, size: 26, color: Colors.amberAccent),
                  label: const Text(
                    'Kamera váltás',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Bezárás gomb
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black87,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Célkereszt jelzés középen
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amberAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
