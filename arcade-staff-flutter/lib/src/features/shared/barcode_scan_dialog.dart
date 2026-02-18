import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScanDialog extends StatefulWidget {
  const BarcodeScanDialog({
    super.key,
    this.title = 'Scan barcode',
  });

  final String title;

  @override
  State<BarcodeScanDialog> createState() => _BarcodeScanDialogState();
}

class _BarcodeScanDialogState extends State<BarcodeScanDialog> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 420,
        height: 500,
        child: Column(
          children: [
            AppBar(title: Text(widget.title), automaticallyImplyLeading: false),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  if (_done) return;
                  final raw = capture.barcodes.firstOrNull?.rawValue;
                  if (raw == null || raw.trim().isEmpty) return;
                  _done = true;
                  Navigator.of(context).pop(raw.trim());
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )
          ],
        ),
      ),
    );
  }
}
