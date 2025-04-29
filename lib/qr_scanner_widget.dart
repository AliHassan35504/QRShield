// qr_scanner_widget.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'web_qr_scanner.dart';

class QrScannerWidget extends StatelessWidget {
  final Function(String) onScanned;

  const QrScannerWidget({super.key, required this.onScanned}); // Use super.key

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Use the web QR scanner for web platforms
      return WebQrScanner(onScanned: onScanned);
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Use mobile scanner for Android and iOS platforms
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
    } else {
      return Center(
        child: Text("QR scanning not supported on this platform."),
      );
    }
  }
}
