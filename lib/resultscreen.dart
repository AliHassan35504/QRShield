// lib/resultscreen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_file/open_file.dart';

import 'offline_url_checker.dart';
import 'url_safety_checker.dart';
import 'view_pdf_screen.dart';

class Resultscreen extends StatefulWidget {
  final String code;
  final VoidCallback closeScreen;
  const Resultscreen({Key? key, required this.code, required this.closeScreen}) : super(key: key);

  @override
  State<Resultscreen> createState() => _ResultscreenState();
}

class _ResultscreenState extends State<Resultscreen> {
  late Future<Map<String, dynamic>> urlSafetyCheck;
  late String dataType;
  Map<String, String> wifiDetails = {};
  Map<String, dynamic> safetyResult = {};
  File? pdfFile;

  @override
  void initState() {
    super.initState();
    dataType = _detectQRDataType(widget.code);
    if (dataType == 'WiFi') wifiDetails = _parseWiFiDetails(widget.code);
    urlSafetyCheck = _initSafetyCheck();
  }

  Future<Map<String, dynamic>> _initSafetyCheck() async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity == ConnectivityResult.none;

    if (dataType != 'URL' && dataType != 'Form' && dataType != 'WhatsApp') {
      safetyResult = {
        'isSafe': true,
        'message': 'Non-URL content',
        'scores': {},
        'probability': 0.0,
      };
      _saveScan(reportUrl: '');
      return safetyResult;
    }

    if (dataType == 'WhatsApp') {
      safetyResult = {
        'isSafe': true,
        'message': 'WhatsApp links skipped from safety APIs.',
        'scores': {},
        'probability': 0.0,
      };
      _saveScan(reportUrl: '');
      return safetyResult;
    }

    if (isOffline) {
      final checker = OfflineUrlChecker();
      final suspicious = checker.isSuspicious(widget.code);
      final triggers = checker.getTriggers(widget.code);
      final prob = suspicious ? 60.0 : 0.0;

      safetyResult = {
        'isSafe': !suspicious,
        'message': suspicious ? 'Offline: suspicious' : 'Offline: safe',
        'scores': {'heuristics': prob},
        'probability': prob,
      };
      _saveScan(reportUrl: '');
      return safetyResult;
    }

    final res = await UrlSafetyChecker().checkUrlSafety(widget.code);
    safetyResult = {
      'isSafe': res['isSafe'] as bool? ?? true,
      'message': res['message'] as String? ?? 'Unknown',
      'scores': res['scores'] as Map<String, dynamic>? ?? {},
      'probability': res['probability'] as double? ?? 0.0,
    };
    _saveScan(reportUrl: '');
    return safetyResult;
  }

  void _saveScan({required String reportUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('scanHistory').add({
      'userId': user.uid,
      'code': widget.code,
      'type': dataType,
      'isSafe': safetyResult['isSafe'] ?? true,
      'message': safetyResult['message'] ?? '',
      'reportUrl': reportUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _detectQRDataType(String data) {
    final lower = data.toLowerCase();
    if (lower.contains('wa.me') || lower.contains('api.whatsapp.com/send')) return 'WhatsApp';
    if (lower.contains('forms.gle') || lower.contains('docs.google.com/forms')) return 'Form';
    if (RegExp(r'^https?://').hasMatch(lower)) return 'URL';
    if (RegExp(r'^\+?[0-9]{6,15}$').hasMatch(data)) return 'Phone';
    if (RegExp(r'^\w+[\w.-]*@[\w.-]+\.\w{2,4}$').hasMatch(data)) return 'Email';
    if (data.startsWith('WIFI:')) return 'WiFi';
    return 'Text';
  }

  Map<String, String> _parseWiFiDetails(String raw) {
    final details = <String, String>{};
    for (final match in RegExp(r'(S|T|P):([^;]*)').allMatches(raw)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        details[key == 'S' ? 'SSID' : key == 'T' ? 'Encryption' : 'Password'] = value;
      }
    }
    return details;
  }

  Future<void> _generatePdfReport() async {
    final user = FirebaseAuth.instance.currentUser;
    final pdf = pw.Document();
    final now = DateTime.now();
    final scores = safetyResult['scores'] as Map<String, dynamic>? ?? {};
    final prob = safetyResult['probability'] as double? ?? 0.0;

    pdf.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("QRSHIELD - Threat Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text("User: ${user?.email ?? 'Unknown'}"),
            pw.Text("Time: $now"),
            pw.Text("Type: $dataType"),
            pw.SizedBox(height: 8),
            pw.Text("Content: ${widget.code}"),
            pw.SizedBox(height: 12),
            pw.Text("Safety Message: ${safetyResult['message']}"),
            pw.Text("Overall Risk Score: ${prob.toStringAsFixed(1)}%"),
            pw.SizedBox(height: 8),
            pw.Text("Risk Breakdown:"),
            ...scores.entries.map((e) => pw.Text("${e.key}: ${e.value}%")),
          ],
        ),
      ),
    );

    final downloads = Directory('/storage/emulated/0/Download/QRShield');
    if (!downloads.existsSync()) downloads.createSync(recursive: true);
    final file = File('${downloads.path}/report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    pdfFile = file;

    try {
      final ref = FirebaseStorage.instance.ref('reports/${user?.uid}/${file.uri.pathSegments.last}');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      _saveScan(reportUrl: url);
    } catch (e) {
      debugPrint('Firebase upload failed: $e');
      _saveScan(reportUrl: '');
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: file)));
  }

  Future<void> _accessData() async {
    final raw = widget.code.trim();
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    switch (dataType) {
      case 'WhatsApp':
      case 'URL':
      case 'Form':
        if (uri != null && await canLaunchUrl(uri)) await launchUrl(uri);
        break;
      case 'Email':
        await launchUrl(Uri(scheme: 'mailto', path: raw));
        break;
      case 'Phone':
        await launchUrl(Uri(scheme: 'tel', path: raw));
        break;
      default:
        Clipboard.setData(ClipboardData(text: raw));
        _showSnack('Copied to clipboard');
    }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Scanner"),
        leading: BackButton(onPressed: () {
          widget.closeScreen();
          Navigator.pop(context);
        }),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            QrImageView(data: widget.code, size: 180),
            const SizedBox(height: 20),
            Text('Type: $dataType'),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: urlSafetyCheck,
              builder: (ctx, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                final res = snap.data!;
                final prob = (res['probability'] as double?) ?? 0.0;
                final safe = res['isSafe'] == true;

                return Column(
                  children: [
                    Text(res['message'] ?? '', style: TextStyle(color: safe ? Colors.green : Colors.red)),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: prob / 100,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(safe ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _accessData,
                      icon: Icon(Icons.open_in_browser),
                      label: const Text('Open'),
                    ),
                    if (dataType == 'URL' || dataType == 'Form' || dataType == 'WhatsApp') ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _generatePdfReport,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Generate Report'),
                      ),
                      if (pdfFile != null)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: pdfFile!)));
                          },
                          icon: const Icon(Icons.remove_red_eye),
                          label: const Text('View Report'),
                        ),
                    ],
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
