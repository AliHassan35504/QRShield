import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  late String dataType;

  @override
  void initState() {
    super.initState();
    dataType = detectQRDataType(widget.code);

    if (dataType == 'url') {
      urlSafetyCheck = UrlSafetyChecker().checkUrlSafety(widget.code);
      urlSafetyCheck.then((result) {
        saveScanToFirestore(
          scannedData: widget.code,
          type: dataType,
          isSafe: result['isSafe'],
          message: result['message'],
        );
      });
    } else {
      // Save immediately if it's not a URL
      saveScanToFirestore(
        scannedData: widget.code,
        type: dataType,
        isSafe: true,
        message: "Plain data",
      );
    }
  }

  Future<void> saveScanToFirestore({
  required String scannedData,
  required String type,
  required bool isSafe,
  required String message,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance.collection('scanHistory').add({
    'userId': user.uid,
    'code': scannedData,
    'type': type,
    'isSafe': isSafe,
    'message': message,
    'timestamp': FieldValue.serverTimestamp(),
  });

  print("Scan saved to Firestore.");
}

  String detectQRDataType(String data) {
    final urlPattern = RegExp(r'^(http|https)://');
    final emailPattern = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    final phonePattern = RegExp(r'^\+?[0-9]{6,15}$');
    final wifiPattern = RegExp(r'^WIFI:');

    if (urlPattern.hasMatch(data)) return 'URL';
    if (emailPattern.hasMatch(data)) return 'Email';
    if (phonePattern.hasMatch(data)) return '{Phone No.}';
    if (wifiPattern.hasMatch(data)) return 'WiFi';
    return 'Text';
  }

  void _visitUrl() async {
    String url = widget.code.trim();
    if (!url.startsWith("http")) {
      url = "http://$url";
    }
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot open URL")),
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
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: widget.code,
              size: 150,
              version: QrVersions.auto,
            ),
            const SizedBox(height: 20),
            Text(
              "Scanned Result",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.code,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, dynamic>>(
              future: dataType == 'url' ? urlSafetyCheck : Future.value({"isSafe": true, "message": "Not a URL"}),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return CircularProgressIndicator();
                if (snapshot.hasError) return Text("Error: ${snapshot.error}");

                final result = snapshot.data!;
                return Column(
                  children: [
                    Text(
                      result["message"],
                      style: TextStyle(
                        fontSize: 16,
                        color: result["isSafe"] ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Copied to clipboard")),
                        );
                      },
                      child: Text("Copy"),
                    ),
                    if (dataType == 'url') ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _visitUrl,
                        child: Text("Visit Site"),
                      ),
                    ]
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
