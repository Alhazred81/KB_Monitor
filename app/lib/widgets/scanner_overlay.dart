import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
        // Vezérlőgombok a tetején (Vaku + Bezárás)
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
                    size: 32,
                  ),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
                // Bezárás gomb
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
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
