// lib/presentation/screens/scanner_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';
import 'package:sqrprojectatlabendsem/files/presentation/providers/scan_notifier.dart';
import 'package:sqrprojectatlabendsem/files/presentation/screens/analysis_screen.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _torchOn = false;
  bool _isProcessing = false; // 🔥 prevents multiple triggers

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    if (capture.barcodes.isEmpty) return;
    final barcode = capture.barcodes.first;

    final raw = barcode.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isProcessing = true;

    // 🔥 Stop scanner before processing
    await _controller.stop();

    final notifier = ref.read(scanNotifierProvider.notifier);
    final result = await notifier.processQrPayload(raw);

    if (result != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(result: result),
        ),
      );
    }

    // 🔥 CRITICAL: restart scanner after returning
    _isProcessing = false;
    await _controller.start();
    notifier.resumeScanner(); // keep if your provider uses it
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera ──────────────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Overlay ─────────────────────────────────────────────────────
          _ScannerOverlay(),

          // ── Top Bar ─────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.accent.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: AppTheme.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SQR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          await _controller.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        },
                        icon: Icon(
                          _torchOn ? Icons.flashlight_on : Icons.flashlight_off,
                          color: _torchOn ? AppTheme.accent : Colors.white54,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.history,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Hint ──────────────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Point camera at a QR code',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ),
          ),

          // ── Loading overlay ──────────────────────────────────────────────
          Consumer(builder: (ctx, ref, _) {
            final loading = ref.watch(
              scanNotifierProvider.select((s) => s.isLoading),
            );
            if (!loading) return const SizedBox.shrink();
            return Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Scanner Viewfinder Overlay ───────────────────────────────────────────────

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cutoutSize = size.width * 0.68;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 40;
    final rect = Rect.fromLTWH(left, top, cutoutSize, cutoutSize);

    final background = Paint()..color = Colors.black.withOpacity(0.6);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      );

    canvas.drawPath(
      path..fillType = PathFillType.evenOdd,
      background,
    );

    final cornerPaint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;
    const r = 12.0;

    // corners
    canvas.drawLine(Offset(left + r, top), Offset(left + r + cornerLen, top), cornerPaint);
    canvas.drawLine(Offset(left, top + r), Offset(left, top + r + cornerLen), cornerPaint);

    canvas.drawLine(
        Offset(left + cutoutSize - r - cornerLen, top),
        Offset(left + cutoutSize - r, top),
        cornerPaint);
    canvas.drawLine(
        Offset(left + cutoutSize, top + r),
        Offset(left + cutoutSize, top + r + cornerLen),
        cornerPaint);

    canvas.drawLine(
        Offset(left + r, top + cutoutSize),
        Offset(left + r + cornerLen, top + cutoutSize),
        cornerPaint);
    canvas.drawLine(
        Offset(left, top + cutoutSize - r - cornerLen),
        Offset(left, top + cutoutSize - r),
        cornerPaint);

    canvas.drawLine(
        Offset(left + cutoutSize - r - cornerLen, top + cutoutSize),
        Offset(left + cutoutSize - r, top + cutoutSize),
        cornerPaint);
    canvas.drawLine(
        Offset(left + cutoutSize, top + cutoutSize - r - cornerLen),
        Offset(left + cutoutSize, top + cutoutSize - r),
        cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}