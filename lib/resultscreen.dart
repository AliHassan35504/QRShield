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
import 'package:path_provider/path_provider.dart';

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
  bool isGenerating = false;

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

    final collection = FirebaseFirestore.instance.collection('scanHistory');
    final existing = await collection
        .where('userId', isEqualTo: user.uid)
        .where('code', isEqualTo: widget.code)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      final currentReport = doc['reportUrl'] ?? '';
      if (currentReport.isEmpty && reportUrl != null && reportUrl.isNotEmpty) {
        await doc.reference.update({'reportUrl': reportUrl});
      }
    } else {
      await collection.add({
        'userId': user.uid,
        'code': widget.code,
        'type': dataType,
        'isSafe': isSafe,
        'message': message,
        'reportUrl': reportUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _generatePdfReport() async {
    if (safetyResult['isSafe'] == true) return;

    setState(() => isGenerating = true);
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final section = safetyResult;

    final pdf = pw.Document();
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
            ...wifiDetails.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
          ],
          if (whatsappDetails.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text('--- WhatsApp Details ---'),
            ...whatsappDetails.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
          ],
          pw.SizedBox(height: 12),
          pw.Text('1. HEURISTIC (OFFLINE) ANALYSIS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (var key in ['url_scheme', 'is_absolute', 'uses_ip', 'uses_shortener', 'suspicious_tld', 'contains_keywords', 'is_encoded', 'is_long_url'])
            pw.Text('$key: ${section['heuristic']?[key] ?? 'N/A'}'),
          pw.Text('Trigger List:'),
          for (var t in (section['heuristic']?['triggers'] as List? ?? [])) pw.Text('- $t'),
          pw.SizedBox(height: 10),
          pw.Text('2. GOOGLE SAFE BROWSING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Safe: ${section['google_safe']}'),
          pw.Text('Matched Categories: ${section['google_matches']?.join(', ') ?? 'None'}'),
          pw.Text('Message: ${section['google_message'] ?? 'N/A'}'),
          pw.SizedBox(height: 10),
          pw.Text('3. VIRUSTOTAL SCAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Malicious: ${section['vt_malicious']} / ${section['vt_total']}'),
          pw.Text('Suspicious: ${section['vt_suspicious']}'),
          pw.Text('Safe: ${section['vt_safe']}'),
          pw.Text('Message: ${section['vt_message']}'),
          pw.SizedBox(height: 10),
          pw.Text('4. OPENPHISH FEED', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Listed: ${section['phish_safe'] == false}'),
          pw.Text('Message: ${section['phish_message'] ?? 'N/A'}'),
          pw.SizedBox(height: 10),
          pw.Text('5. IPQUALITYSCORE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          for (var k in ['risk_score', 'malware', 'phishing', 'domain_rank', 'spamming', 'suspicious'])
            pw.Text('$k: ${section['ipq']?[k]}'),
          pw.Text('Message: ${section['ipq']?['message'] ?? 'N/A'}'),
          pw.SizedBox(height: 10),
          pw.Text('6. URLSCAN.IO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Status: ${section['scan_status']}'),
          pw.Text('Result URL: ${section['scan_result']}'),
          pw.Text('Screenshot: ${section['scan_screenshot']}'),
          pw.SizedBox(height: 14),
          pw.Text('FINAL VERDICT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
          pw.Text('Score: ${section['final_score']}%'),
          pw.Text('Classification: ${section['isSafe'] == true ? 'Safe' : 'Malicious'}'),
          pw.Text('Recommendation: ${section['finalVerdict']}'),
        ],
      ),
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    pdfFile = file;

    try {
      final ref = FirebaseStorage.instance.ref('reports/${user?.uid}/${file.uri.pathSegments.last}');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      await _saveScan(
        isSafe: false,
        message: section['finalVerdict'] ?? '',
        reportUrl: downloadUrl,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    }

    setState(() => isGenerating = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: file)));
  }

  Future<void> _accessOrCopyData() async {
    final uri = Uri.tryParse(widget.code.startsWith('http') ? widget.code : 'https://${widget.code}');
    if (['URL', 'Form', 'WhatsApp'].contains(dataType) && uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Clipboard.setData(ClipboardData(text: widget.code));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }

  String _detectQRDataType(String data) {
    final d = data.toLowerCase();
    if (d.contains('wa.me') || d.contains('api.whatsapp.com/send')) return 'WhatsApp';
    if (d.contains('forms.gle') || d.contains('docs.google.com/forms')) return 'Form';
    if (d.startsWith('http')) return 'URL';
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
      'number': uri?.pathSegments.firstOrNull ?? '',
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
            builder: (_, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();
              final d = snap.data!;
              final safe = d['isSafe'] == true;
              final score = (d['final_score'] as num? ?? 0).toDouble();
              final suggestion = safe
                  ? 'You may proceed to access this data.'
                  : 'Do not proceed. This QR code may be malicious.';

              return Column(children: [
                Text(d['finalVerdict'] ?? '', style: TextStyle(color: safe ? Colors.green : Colors.red)),
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
                  isGenerating
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _generatePdfReport,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Generate Report'),
                        ),
                if (pdfFile != null)
                  TextButton.icon(
                    icon: const Icon(Icons.remove_red_eye),
                    label: const Text('View Report'),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: pdfFile!)));
                    },
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}
