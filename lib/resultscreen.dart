// lib/resultscreen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'url_safety_checker.dart';

class Resultscreen extends StatefulWidget {
  final String code;
  final VoidCallback closeScreen;

  const Resultscreen({
    Key? key,
    required this.closeScreen,
    required this.code,
  }) : super(key: key);

  @override
  State<Resultscreen> createState() => _ResultscreenState();
}

class _ResultscreenState extends State<Resultscreen> {
  late Future<Map<String, dynamic>> urlSafetyCheck;
  late String dataType;

  @override
  void initState() {
    super.initState();

    // 1️⃣ Detect type:
    dataType = _detectQRDataType(widget.code);

    // 2️⃣ Trigger safety check & save:
    if (dataType == 'URL' || dataType == 'Form') {
      urlSafetyCheck = UrlSafetyChecker().checkUrlSafety(widget.code);
      urlSafetyCheck.then((res) {
        _saveScan(
          scannedData: widget.code,
          type: dataType,
          isSafe: res['isSafe'],
          message: res['message'],
        );
      });
    } else {
      // Non-URL types save immediately as “safe”
      _saveScan(
        scannedData: widget.code,
        type: dataType,
        isSafe: true,
        message: 'Non-URL data',
      );
      // for consistency:
      urlSafetyCheck = Future.value({
        'isSafe': true,
        'message': 'N/A',
      });
    }
  }

  Future<void> _saveScan({
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
  }

  String _detectQRDataType(String data) {
    final lower = data.toLowerCase();
    // Google Forms shared links
    if (lower.contains('forms.gle') || lower.contains('docs.google.com/forms')) {
      return 'Form';
    }
    if (RegExp(r'^(http|https)://').hasMatch(lower)) return 'URL';
    if (RegExp(r'^[\w.\-]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(data)) return 'Email';
    if (RegExp(r'^\+?[0-9]{6,15}$').hasMatch(data)) return 'Phone';
    if (data.startsWith('WIFI:')) return 'WiFi';
    return 'Text';
  }

  Future<void> _accessData() async {
    final raw = widget.code.trim();
    switch (dataType) {
      case 'URL':
      case 'Form':
        var url = raw.startsWith(RegExp(r'https?://')) ? raw : 'https://$raw';
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          _showSnack('Cannot open link');
        }
        break;

      case 'Email':
        final emailUri = Uri(
          scheme: 'mailto',
          path: raw,
        );
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri);
        } else {
          _showSnack('Cannot open mail client');
        }
        break;

      case 'Phone':
        final telUri = Uri(scheme: 'tel', path: raw);
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        } else {
          _showSnack('Cannot initiate call');
        }
        break;

      case 'WiFi':
        // Format: WIFI:S:SSID;T:WPA;P:password;;
        _showSnack('Credentials copied');
        Clipboard.setData(ClipboardData(text: raw));
        break;

      case 'Text':
      default:
        _showSnack('Text copied');
        Clipboard.setData(ClipboardData(text: raw));
        break;
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          color: Colors.black87,
          onPressed: () {
            widget.closeScreen();
            Navigator.pop(context);
          },
        ),
        centerTitle: true,
        title: const Text(
          'QR Scanner',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: widget.code,
                size: 180,
                version: QrVersions.auto,
              ),
              const SizedBox(height: 24),
              Text(
                'Type: $dataType',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                widget.code,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Safety / Non-URL placeholder
              FutureBuilder<Map<String, dynamic>>(
                future: urlSafetyCheck,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final res = snap.data!;
                  final msg = res['message'] as String;
                  final safe = res['isSafe'] as bool;
                  final color = safe ? Colors.green : Colors.red;
                  return Column(
                    children: [
                      Text(msg, style: TextStyle(color: color)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(
                          dataType == 'URL' || dataType == 'Form'
                              ? Icons.open_in_browser
                              : dataType == 'Email'
                                  ? Icons.email
                                  : dataType == 'Phone'
                                      ? Icons.phone
                                      : dataType == 'WiFi'
                                          ? Icons.wifi
                                          : Icons.copy,
                        ),
                        label: Text(
                          dataType == 'URL' || dataType == 'Form'
                              ? 'Visit Site'
                              : dataType == 'Email'
                                  ? 'Send Email'
                                  : dataType == 'Phone'
                                      ? 'Call Number'
                                      : dataType == 'WiFi'
                                          ? 'Copy Wi-Fi'
                                          : 'Copy Text',
                        ),
                        onPressed: _accessData,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
