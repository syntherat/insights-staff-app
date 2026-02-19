import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanDialog extends StatefulWidget {
  const BarcodeScanDialog({
    super.key,
    this.title = 'Scan code',
  });

  final String title;

  @override
  State<BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<BarcodeScanDialog>
    with SingleTickerProviderStateMixin {
  bool _done = false;
  bool _torchOn = false;
  late final MobileScannerController _controller;
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: (capture) {
              if (_done) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw == null || raw.trim().isEmpty) return;
              _done = true;
              Navigator.of(context).pop(raw.trim());
            },
          ),
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, _) => _ScannerOverlay(
              torchOn: _torchOn,
              onToggleTorch: () async {
                await _controller.toggleTorch();
                if (!mounted) return;
                setState(() => _torchOn = !_torchOn);
              },
              scanProgress: _scanLineController.value,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({
    required this.torchOn,
    required this.onToggleTorch,
    required this.scanProgress,
  });

  final bool torchOn;
  final VoidCallback onToggleTorch;
  final double scanProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final frameSize = width.clamp(230.0, 340.0).toDouble();
        final left = (width - frameSize) / 2;
        final top = (height - frameSize) / 2.5;
        final scanLineTop = top + 8 + (frameSize - 16) * scanProgress;

        return Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, height: top, child: _dim()),
            Positioned(
                top: top + frameSize,
                left: 0,
                right: 0,
                bottom: 0,
                child: _dim()),
            Positioned(
                top: top,
                left: 0,
                width: left,
                height: frameSize,
                child: _dim()),
            Positioned(
                top: top,
                right: 0,
                width: left,
                height: frameSize,
                child: _dim()),
            Positioned(
              top: top,
              left: left,
              width: frameSize,
              height: frameSize,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: const Color(0xCCFFFFFF), width: 1.6),
                ),
              ),
            ),
            Positioned(
              top: scanLineTop,
              left: left + 10,
              width: frameSize - 20,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9B4A),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x88FF9B4A),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: top + frameSize + 14,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      onPressed: onToggleTorch,
                      icon: Icon(
                        torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: torchOn ? const Color(0xFFFF9B4A) : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: const Text(
                        'Scan QR or barcode inside the square',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dim() => Container(color: Colors.black.withValues(alpha: 0.5));
}
