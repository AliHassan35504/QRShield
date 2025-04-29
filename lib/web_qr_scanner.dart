// web_qr_scanner.dart
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:js/js.dart';

@JS('Html5Qrcode') // Access the global Html5Qrcode JavaScript class
class Html5Qrcode {
  external Html5Qrcode(String elementId); // Constructor
  external void start(
      dynamic config, Function(dynamic) onSuccess, Function(String) onError);
  external void stop();
}

class WebQrScanner extends StatefulWidget {
  final Function(String) onScanned;

  const WebQrScanner({Key? key, required this.onScanned}) : super(key: key);

  @override
  _WebQrScannerState createState() => _WebQrScannerState();
}

class _WebQrScannerState extends State<WebQrScanner> {
  Html5Qrcode? html5Qrcode;

  @override
  void initState() {
    super.initState();
    _initializeWebScanner();
  }

  void _initializeWebScanner() {
    // Create a div for the QR code scanner
    final div = html.DivElement()..id = 'qr-code-scanner';
    html.document.body?.append(div);

    // Initialize the Html5Qrcode object with the div ID
    html5Qrcode = Html5Qrcode('qr-code-scanner');
    html5Qrcode?.start(
      {
        'fps': 10,
        'qrbox': 250,
        'aspectRatio': 1.0,
        'disableFlip': false,
      },
      allowInterop((result) {
        widget.onScanned(result['decodedText']);
      }),
      allowInterop((error) {
        print("QR scan error: $error");
      }),
    );
  }

  @override
  void dispose() {
    html5Qrcode?.stop();
    html.document.getElementById('qr-code-scanner')?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: 'qr-code-scanner');
  }
}
