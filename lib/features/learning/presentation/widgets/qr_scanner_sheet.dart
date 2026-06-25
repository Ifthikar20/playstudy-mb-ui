import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen camera sheet that scans a QR code and returns its raw value
/// (typically a URL) to the caller. Returns `null` if the user dismisses it.
///
///   final url = await Navigator.of(context).push<String>(
///     MaterialPageRoute(fullscreenDialog: true, builder: (_) => const QrScannerPage()),
///   );
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null || raw.isEmpty) continue;
      _done = true;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        // dark vignette + cut-out window
        const _ScannerOverlay(),
        // close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          right: 6,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // torch toggle
        Positioned(
          top: MediaQuery.of(context).padding.top + 6,
          left: 6,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: _ctrl,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () => _ctrl.toggleTorch(),
              );
            },
          ),
        ),
        // caption
        Positioned(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).padding.bottom + 32,
          child: const Text(
            'Point at a QR code that contains a study link.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
          ),
        ),
      ]),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = c.maxHeight;
      final size = (w * 0.7).clamp(220.0, 320.0);
      final left = (w - size) / 2;
      final top = (h - size) / 2 - 40;
      return IgnorePointer(
        child: Stack(children: [
          // dimmed background
          Container(color: Colors.black.withOpacity(0.55)),
          // cut a transparent rounded window
          Positioned(
            left: left,
            top: top,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    });
  }
}
