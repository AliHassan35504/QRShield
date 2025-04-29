import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Resultscreen extends StatefulWidget {
  final String code;
  final Function() closeScreen;

  const Resultscreen({Key? key, required this.closeScreen, required this.code}) : super(key: key);

  @override
  _ResultscreenState createState() => _ResultscreenState();
}

class _ResultscreenState extends State<Resultscreen> {
  String? dataType;
  bool isSafe = true;
  String safetyMessage = 'Checking...';

  @override
  void initState() {
    super.initState();

    dataType = detectQRDataType(widget.code);
    saveScanResult(widget.code, dataType!);

    if (dataType == 'url') {
      checkUrlSafety(widget.code);
    } else {
      setState(() {
        safetyMessage = 'No safety check required.';
      });
    }
  }

  String detectQRDataType(String data) {
    final urlPattern = RegExp(r'^(http|https):\/\/');
    final emailPattern = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    final phonePattern = RegExp(r'^\+?[0-9]{10,15}$');
    final wifiPattern = RegExp(r'^WIFI:');

    if (urlPattern.hasMatch(data)) return 'url';
    if (emailPattern.hasMatch(data)) return 'email';
    if (phonePattern.hasMatch(data)) return 'phone';
    if (wifiPattern.hasMatch(data)) return 'wifi';
    return 'text';
  }

  Future<void> saveScanResult(String data, String type) async {
    await FirebaseFirestore.instance.collection('scan_results').add({
      'data': data,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> checkUrlSafety(String url) async {
    // Replace this with actual safety API logic
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      isSafe = true;
      safetyMessage = '✅ This URL is safe.';
    });
  }

  void _launchUrl() async {
    final uri = Uri.parse(widget.code);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cannot open the URL.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (dataType == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.closeScreen();
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            QrImageView(data: widget.code, size: 200),
            const SizedBox(height: 20),
            SelectableText(
              widget.code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.blueAccent),
            ),
            const SizedBox(height: 10),
            Text('Type: $dataType', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Safety: $safetyMessage', style: TextStyle(color: isSafe ? Colors.green : Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard.")));
              },
              icon: const Icon(Icons.copy),
              label: const Text("Copy"),
            ),
            if (dataType == 'url') ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _launchUrl,
                icon: const Icon(Icons.open_in_browser),
                label: const Text("Open URL"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
