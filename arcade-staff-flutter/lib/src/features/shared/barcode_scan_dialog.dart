import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanDialog extends StatefulWidget {
  const BarcodeScanDialog({
    super.key,
    this.title = 'Scan code',
    this.continuousMode = false,
    this.onScan,
  });

  final String title;
  final bool continuousMode;
  final Future<String?> Function(String code)? onScan;

  @override
  State<BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<BarcodeScanDialog>
    with SingleTickerProviderStateMixin {
  bool _done = false;
  bool _torchOn = false;
  bool _processing = false;
  String? _lastMessage;
  bool _lastSuccess = true;
  late final MobileScannerController _controller;
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.itf,
        BarcodeFormat.pdf417,
        BarcodeFormat.aztec,
        BarcodeFormat.dataMatrix,
      ],
    );
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
            onDetect: (capture) async {
              if (_done || _processing) return;
              final raw = capture.barcodes
                  .map((b) => b.rawValue?.trim())
                  .whereType<String>()
                  .firstWhere(
                    (value) => value.isNotEmpty,
                    orElse: () => '',
                  );
              if (raw.isEmpty) return;

              if (!widget.continuousMode) {
                _done = true;
                Navigator.of(context).pop(raw);
                return;
              }

              // Continuous mode
              setState(() => _processing = true);
              try {
                final result = await widget.onScan?.call(raw);
                if (!mounted) return;
                setState(() {
                  _lastMessage = result ?? 'Scanned successfully';
                  _lastSuccess =
                      result == null || !result.toLowerCase().contains('error');
                  _processing = false;
                });
                await Future.delayed(const Duration(milliseconds: 1500));
                if (!mounted) return;
                setState(() => _lastMessage = null);
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _lastMessage = e.toString();
                  _lastSuccess = false;
                  _processing = false;
                });
                await Future.delayed(const Duration(milliseconds: 2000));
                if (!mounted) return;
                setState(() => _lastMessage = null);
              }
            },
          ),
          AnimatedBuilder(
            animation: _scanLineController,
            builder: (context, _) => _ScannerOverlay(
              scanProgress: _scanLineController.value,
              message: _lastMessage,
              isSuccess: _lastSuccess,
              isProcessing: _processing,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton.filledTonal(
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (!mounted) return;
                      setState(() => _torchOn = !_torchOn);
                    },
                    icon: Icon(
                      _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      color: _torchOn ? const Color(0xFFFF9B4A) : null,
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
    required this.scanProgress,
    this.message,
    this.isSuccess = true,
    this.isProcessing = false,
  });

  final double scanProgress;
  final String? message;
  final bool isSuccess;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        // Make frame more responsive for small screens
        final frameSize = (width * 0.75).clamp(200.0, 340.0).toDouble();
        final left = (width - frameSize) / 2;
        final top = (height - frameSize) / 2.4;
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
              top: top + frameSize + 20,
              left: 16,
              right: 16,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: message != null
                      ? Container(
                          key: ValueKey(message),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? Colors.green.withValues(alpha: 0.9)
                                : Colors.red.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSuccess ? Icons.check_circle : Icons.error,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('default'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x33FFFFFF)),
                          ),
                          child: Text(
                            isProcessing
                                ? 'Processing...'
                                : 'Put the code into the frame',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
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
