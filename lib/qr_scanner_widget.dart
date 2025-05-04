// qr_scanner_widget.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'web_qr_scanner_stub.dart'
    if (dart.library.html) 'web_qr_scanner.dart'; // conditional import

class QrScannerWidget extends StatelessWidget {
  final Function(String) onScanned;

  const QrScannerWidget({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebQrScanner(onScanned: onScanned); // from imported stub or web file
    } else {
      return MobileScanner(
        onDetect: (BarcodeCapture capture) {
          for (final barcode in capture.barcodes) {
            final String? code = barcode.rawValue;
            if (code != null) {
              onScanned(code);
            }
          }
        },
      );
    }
  }
}
