// lib/resultscreen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
  Map<String, String> whatsappDetails = {};
  Map<String, dynamic> safetyResult = {};
  File? pdfFile;

  @override
  void initState() {
    super.initState();
    dataType = _detectQRDataType(widget.code);
    if (dataType == 'WiFi') wifiDetails = _parseWiFiDetails(widget.code);
    if (dataType == 'WhatsApp') whatsappDetails = _parseWhatsAppDetails(widget.code);
    urlSafetyCheck = _initSafetyCheck();
  }

  Future<Map<String, dynamic>> _initSafetyCheck() async {
    final checker = UrlSafetyChecker();
    try {
      final isOfflineType = ['WiFi', 'WhatsApp', 'Form', 'Phone', 'Email', 'Text'].contains(dataType);
      final result = isOfflineType
          ? await checker.checkOfflineOnly(widget.code, type: dataType)
          : await checker.checkFullReport(widget.code);

      safetyResult = result;

      await _saveScan(
        isSafe: result['isSafe'] == true,
        message: result['finalVerdict'] ?? 'Unknown',
        reportUrl: null,
      );

      return result;
    } catch (e) {
      return {
        'isSafe': false,
        'final_score': 100,
        'finalVerdict': 'Scan Failed: $e',
      };
    }
  }

  Future<void> _saveScan({required bool isSafe, required String message, String? reportUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('scanHistory').add({
      'userId': user.uid,
      'code': widget.code,
      'type': dataType,
      'isSafe': isSafe,
      'message': message,
      'reportUrl': reportUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

   Future<void> _generatePdfReport() async {
    if (safetyResult['isSafe'] == true) return;

    final user = FirebaseAuth.instance.currentUser;
    final pdf = pw.Document();
    final now = DateTime.now();
    final section = safetyResult;

    pdf.addPage(pw.Page(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('QRSHIELD Threat Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('User: ${user?.email ?? 'Unknown'}'),
          pw.Text('Date: $now'),
          pw.Text('Type: $dataType'),
          pw.Text('Raw Data: ${widget.code}'),
          if (wifiDetails.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('--- Wi-Fi Details ---'),
            ...wifiDetails.entries.map((e) => pw.Text('${e.key}: ${e.value}')).toList(),
          ],
          if (whatsappDetails.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('--- WhatsApp Details ---'),
            ...whatsappDetails.entries.map((e) => pw.Text('${e.key}: ${e.value}')).toList(),
          ],
          pw.SizedBox(height: 12),

          pw.Text('1. HEURISTIC (OFFLINE) ANALYSIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (var key in ['url_scheme', 'is_absolute', 'uses_ip', 'uses_shortener', 'suspicious_tld', 'contains_keywords', 'is_encoded', 'is_long_url'])
            pw.Text('$key: ${section['heuristic']?[key]?.toString() ?? 'N/A'}'),
          pw.Text('Trigger List:'),
          for (var trigger in (section['heuristic']?['triggers'] as List? ?? [])) pw.Text('• $trigger'),

          pw.SizedBox(height: 10),
          pw.Text('2. GOOGLE SAFE BROWSING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Safe: ${section['google_safe'] ?? 'N/A'}'),
          pw.Text('Matched Categories: ${section['google_matches']?.join(', ') ?? 'None'}'),
          pw.Text('Details: ${section['google_message'] ?? 'N/A'}'),

          pw.SizedBox(height: 10),
          pw.Text('3. VIRUSTOTAL SCAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Malicious Engines: ${section['vt_malicious'] ?? 'N/A'}'),
          pw.Text('Suspicious Engines: ${section['vt_suspicious'] ?? 'N/A'}'),
          pw.Text('Total Engines: ${section['vt_total'] ?? 'N/A'}'),
          pw.Text('Safe: ${section['vt_safe'] ?? 'N/A'}'),
          pw.Text('Message: ${section['vt_message'] ?? 'N/A'}'),

          pw.SizedBox(height: 10),
          pw.Text('4. OPENPHISH FEED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Listed in Feed: ${section['phish_safe'] == false}'),
          pw.Text('Message: ${section['phish_message'] ?? 'N/A'}'),

          pw.SizedBox(height: 10),
          pw.Text('5. IPQUALITYSCORE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (var key in ['risk_score', 'malware', 'phishing', 'domain_rank', 'spamming', 'suspicious'])
            pw.Text('$key: ${section['ipq']?[key]?.toString() ?? 'N/A'}'),
          pw.Text('Message: ${section['ipq']?['message'] ?? 'N/A'}'),

          pw.SizedBox(height: 10),
          pw.Text('6. URLSCAN.IO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Status: ${section['scan_status'] ?? 'N/A'}'),
          pw.Text('Result URL: ${section['scan_result'] ?? 'N/A'}'),
          pw.Text('Screenshot URL: ${section['scan_screenshot'] ?? 'N/A'}'),

          pw.SizedBox(height: 16),
          pw.Text('FINAL VERDICT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Overall Risk Score: ${(section['final_score'] ?? 0).toString()}%'),
          pw.Text('Classification: ${section['isSafe'] == false ? 'Malicious' : 'Safe'}'),
          pw.Text('Recommendation: ${section['finalVerdict'] ?? 'N/A'}'),
        ],
      ),
    ));

    final dir = Directory('/storage/emulated/0/Download/QRShield');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    pdfFile = file;
    setState(() {});

    try {
      final ref = FirebaseStorage.instance.ref('reports/${user?.uid}/${file.uri.pathSegments.last}');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _saveScan(isSafe: false, message: section['finalVerdict'] ?? '', reportUrl: url);
    } catch (_) {}

    Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: pdfFile!)));
  }

  Future<void> _accessOrCopyData() async {
    final raw = widget.code.trim();
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    final isOpenable = ['URL', 'Form', 'WhatsApp'].contains(dataType);

    if (isOpenable && uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: raw));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  String _detectQRDataType(String data) {
    final l = data.toLowerCase();
    if (l.contains('wa.me') || l.contains('api.whatsapp.com/send')) return 'WhatsApp';
    if (l.contains('forms.gle') || l.contains('docs.google.com/forms')) return 'Form';
    if (l.startsWith('http')) return 'URL';
    if (data.startsWith('WIFI:')) return 'WiFi';
    if (RegExp(r'^\+?[0-9]{6,15}$').hasMatch(data)) return 'Phone';
    if (RegExp(r'^\w+@[\w\-]+\.\w{2,4}$').hasMatch(data)) return 'Email';
    return 'Text';
  }

  Map<String, String> _parseWiFiDetails(String raw) {
    final out = <String, String>{};
    for (final m in RegExp(r'(S|T|P):([^;]*)').allMatches(raw)) {
      final k = m.group(1), v = m.group(2);
      if (k != null && v != null) {
        if (k == 'S') out['SSID'] = v;
        if (k == 'T') out['Encryption'] = v;
        if (k == 'P') out['Password'] = v;
      }
    }
    return out;
  }

  Map<String, String> _parseWhatsAppDetails(String raw) {
    final uri = Uri.tryParse(raw);
    return {
      'number': uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.first : '',
      'text': uri?.queryParameters['text'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        leading: BackButton(onPressed: () {
          widget.closeScreen();
          Navigator.pop(context);
        }),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          QrImageView(data: widget.code, size: 180),
          const SizedBox(height: 12),
          Text('Type: $dataType', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Data: ${widget.code}'),
          const SizedBox(height: 8),
          ...wifiDetails.entries.map((e) => Text('${e.key}: ${e.value}')),
          ...whatsappDetails.entries.map((e) => Text('WhatsApp ${e.key}: ${e.value}')),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: urlSafetyCheck,
            builder: (ctx, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final d = snap.data!;
              final safe = d['isSafe'] == true;
              final score = (d['final_score'] as num? ?? 0).toDouble();
              final suggestion = safe
                  ? 'You may proceed to access this data.'
                  : '⚠️ Do not proceed. This QR code may be malicious.';

              return Column(children: [
                Text(d['finalVerdict']?.toString() ?? '', style: TextStyle(color: safe ? Colors.green : Colors.red)),
                LinearProgressIndicator(value: score / 100, color: safe ? Colors.green : Colors.red),
                const SizedBox(height: 6),
                Text(suggestion, style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _accessOrCopyData,
                  icon: Icon(['URL', 'Form', 'WhatsApp'].contains(dataType) ? Icons.open_in_browser : Icons.copy),
                  label: Text(['URL', 'Form', 'WhatsApp'].contains(dataType) ? 'Open Link' : 'Copy Data'),
                ),
                const SizedBox(height: 4),
                if (!safe)
                  ElevatedButton.icon(
                    onPressed: _generatePdfReport,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generate Report')),
                if (pdfFile != null)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ViewPdfScreen(file: pdfFile!)),
                    ),
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('View Report')),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
