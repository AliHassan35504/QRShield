import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'url_safety_checker.dart';

class Resultscreen extends StatefulWidget {
  final String code;
  final Function() closeScreen;

  const Resultscreen({super.key, required this.closeScreen, required this.code});

  @override
  _ResultscreenState createState() => _ResultscreenState();
}

class _ResultscreenState extends State<Resultscreen> {
  late Future<Map<String, dynamic>> urlSafetyCheck;
  String dataType = 'text';
  bool isSafe = true;
  String safetyMessage = '';

  @override
  void initState() {
    super.initState();
    dataType = detectQRDataType(widget.code);
    if (dataType == 'url') {
      urlSafetyCheck = UrlSafetyChecker().checkUrlSafety(widget.code);
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

  Future<void> _launchUrl(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot open the URL.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            widget.closeScreen();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        ),
        centerTitle: true,
        title: const Text(
          "QR Scanner",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(data: widget.code, size: 150),
            const SizedBox(height: 20),
            Text("Scanned Result", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SelectableText(
              widget.code,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            if (dataType == 'url')
              FutureBuilder<Map<String, dynamic>>(
                future: urlSafetyCheck,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }
                  final result = snapshot.data!;
                  isSafe = result["isSafe"];
                  safetyMessage = result["message"];
                  return Column(
                    children: [
                      Text(
                        safetyMessage,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSafe ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: isSafe ? () => _launchUrl(widget.code) : null,
                        icon: const Icon(Icons.language),
                        label: const Text("Visit Website"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSafe ? Colors.green : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  );
                },
              ),
            if (dataType != 'url')
              Text(
                "Content type: $dataType",
                style: const TextStyle(color: Colors.blueGrey),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copied to clipboard")),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text("Copy"),
            ),
          ],
        ),
      ),
    );
  }
}
