import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/widgets.dart' as pw;
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
    final offlineChecker = OfflineUrlChecker();
    final heurSusp = offlineChecker.isSuspicious(widget.code);
    final heurMsg = heurSusp ? 'Suspicious format or shortener' : 'Format looks OK';
    final heurScore = heurSusp ? 20.0 : 0.0;

    if (dataType != 'URL' && dataType != 'Form' && dataType != 'WhatsApp') {
      final result = {
        'isSafe': heurScore == 0,
        'message': heurMsg,
        'scores': {'Heuristic': heurScore},
        'probability': heurScore,
        'details': {'Heuristic': heurMsg},
      };
      safetyResult = result;
      await _saveScan(isSafe: result['isSafe'] as bool, message: heurMsg, reportUrl: null);
      return result;
    }

    final isOffline = (await Connectivity().checkConnectivity()) == ConnectivityResult.none;

    double googleScore = 0, vtScore = 0, phishScore = 0, ipqsScore = 0;
    String googleMsg = '', vtMsg = '', phishMsg = '', ipqsMsg = '', urlscanMsg = '';
    List<String> extraDetails = [];

    if (!isOffline) {
      try {
        final g = await UrlSafetyChecker().googleCheck(widget.code);
        googleMsg = g['message'] ?? '';
        googleScore = (g['isSafe'] == true) ? 0.0 : 30.0;
      } catch (e) {
        googleMsg = 'Google check failed';
        googleScore = 15.0;
      }

      try {
        final v = await UrlSafetyChecker().virusTotalCheck(widget.code);
        vtMsg = v['message'] ?? '';
        vtScore = (v['isSafe'] == true) ? 0.0 : 30.0;
      } catch (e) {
        vtMsg = 'VirusTotal check failed';
        vtScore = 15.0;
      }

      try {
        final p = await UrlSafetyChecker().openPhishCheck(widget.code);
        phishMsg = p['message'] ?? '';
        phishScore = (p['isSafe'] == true) ? 0.0 : 20.0;
      } catch (e) {
        phishMsg = 'OpenPhish check failed';
        phishScore = 10.0;
      }

      try {
        final ipq = await UrlSafetyChecker().checkWithIPQualityScore(widget.code);
        ipqsMsg = ipq['message'] ?? '';
        ipqsScore = (ipq['isSafe'] == true) ? 0.0 : 20.0;
      } catch (e) {
        ipqsMsg = 'IPQualityScore check failed';
        ipqsScore = 10.0;
      }

      try {
        final uscan = await UrlSafetyChecker().checkWithUrlScan(widget.code);
        urlscanMsg = uscan['message'] ?? '';
        final d = uscan['details'] as List?;
        if (d != null) extraDetails.addAll(d.map((e) => e.toString()));
      } catch (_) {}
    }

    final total = heurScore + googleScore + vtScore + phishScore + ipqsScore;
    final isSafe = total == 0;

    final result = {
      'isSafe': isSafe,
      'message': isSafe
          ? 'No threats detected (Risk 0%)'
          : 'Threats detected (Risk ${total.toStringAsFixed(1)}%)',
      'scores': {
        'Heuristic': heurScore,
        'Google Safe Browsing': googleScore,
        'VirusTotal': vtScore,
        'OpenPhish': phishScore,
        'IPQualityScore': ipqsScore,
      },
      'probability': total,
      'details': {
        'Heuristic': heurMsg,
        'Google Safe Browsing': googleMsg,
        'VirusTotal': vtMsg,
        'OpenPhish': phishMsg,
        'IPQualityScore': ipqsMsg,
        if (urlscanMsg.isNotEmpty) 'urlscan.io': urlscanMsg,
        if (extraDetails.isNotEmpty) 'URLScan Details': extraDetails.join('\n')
      },
    };

    safetyResult = result;
    await _saveScan(isSafe: isSafe, message: result['message'] as String, reportUrl: null);
    return result;
  }

  Future<void> _saveScan({required bool isSafe, required String message, String? reportUrl}) async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    await FirebaseFirestore.instance.collection('scanHistory').add({
      'userId': u.uid,
      'code': widget.code,
      'type': dataType,
      'isSafe': isSafe,
      'message': message,
      'reportUrl': reportUrl ?? '',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  String _detectQRDataType(String d) {
    final l = d.toLowerCase();
    if (l.contains('wa.me') || l.contains('api.whatsapp.com/send')) return 'WhatsApp';
    if (l.contains('forms.gle') || l.contains('docs.google.com/forms')) return 'Form';
    if (l.startsWith('http')) return 'URL';
    if (d.startsWith('WIFI:')) return 'WiFi';
    if (RegExp(r'^\+?[0-9]{6,15}$').hasMatch(d)) return 'Phone';
    if (RegExp(r'^\w+@[\w\-]+\.\w{2,4}$').hasMatch(d)) return 'Email';
    return 'Text';
  }

  Map<String, String> _parseWiFiDetails(String raw) {
    final out = <String, String>{};
    for (final m in RegExp(r'(S|T|P):([^;]*)').allMatches(raw)) {
      final k = m.group(1), v = m.group(2);
      if (k != null && v != null) out[k] = v;
    }
    return {
      'SSID': out['S'] ?? '',
      'Encryption': out['T'] ?? '',
      'Password': out['P'] ?? '',
    };
  }

  Map<String, String> _parseWhatsAppDetails(String raw) {
    final uri = Uri.tryParse(raw);
    return {
      'number': (uri?.pathSegments.isNotEmpty ?? false) ? uri!.pathSegments.first : '',
      'text': uri?.queryParameters['text'] ?? '',
    };
  }

  Future<void> _generatePdfReport() async {
    if (safetyResult['isSafe'] == true) return;
    final u = FirebaseAuth.instance.currentUser;
    final pdf = pw.Document();
    final now = DateTime.now();

    pdf.addPage(pw.Page(build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('QRSHIELD Threat Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('User: ${u?.email ?? 'Unknown'}'),
        pw.Text('Date: $now'),
        pw.SizedBox(height: 10),
        pw.Text('Type: $dataType'),
        pw.Text('Data: ${widget.code}'),
        if (wifiDetails.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('--- WiFi Info ---'),
          ...wifiDetails.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
        ],
        if (whatsappDetails.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text('--- WhatsApp Info ---'),
          ...whatsappDetails.entries.map((e) => pw.Text('${e.key}: ${e.value}')),
        ],
        pw.SizedBox(height: 12),
        pw.Text('Message: ${safetyResult['message']}'),
        pw.Text('Total Risk: ${(safetyResult['probability'] as num).toStringAsFixed(1)}%'),
        pw.SizedBox(height: 8),
        pw.Text('--- Scoring Breakdown ---'),
        ...((safetyResult['scores'] as Map<String, dynamic>).entries.map(
          (e) => pw.Text('${e.key}: ${e.value.toString()}%'))),
        pw.SizedBox(height: 8),
        pw.Text('--- Source Explanations ---'),
        ...((safetyResult['details'] as Map<String, dynamic>).entries.expand((e) {
          if (e.value is String) return [pw.Text('${e.key}: ${e.value}')];
          if (e.value is List) {
            return [
              pw.Text('${e.key}:'),
              ...((e.value as List).map((line) => pw.Bullet(text: line.toString())))
            ];
          }
          return [pw.Text('${e.key}: ${e.value}')];
        })),
      ],
    )));

    final dir = Directory('/storage/emulated/0/Download/QRShield');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    pdfFile = file;
    setState(() {});

    try {
      final ref = FirebaseStorage.instance.ref('reports/${u?.uid}/${file.uri.pathSegments.last}');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      await _saveScan(isSafe: false, message: safetyResult['message'], reportUrl: url);
    } catch (_) {}
    Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: pdfFile!)));
  }

  Future<void> _accessData() async {
    final raw = widget.code.trim();
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    switch (dataType) {
      case 'URL':
      case 'Form':
      case 'WhatsApp':
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied')));
    }
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
        child: Column(
          children: [
            QrImageView(data: widget.code, size: 180),
            const SizedBox(height: 12),
            Text('Type: $dataType'),
            if (wifiDetails.isNotEmpty)
              ...wifiDetails.entries.map((e) => Text('${e.key}: ${e.value}')),
            if (whatsappDetails.isNotEmpty)
              ...whatsappDetails.entries.map((e) => Text('WhatsApp ${e.key}: ${e.value}')),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: urlSafetyCheck,
              builder: (ctx, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();
                final d = snap.data!;
                final safe = d['isSafe'] == true;
                final pct = ((d['probability'] as num?) ?? 0) / 100;

                return Column(children: [
                  Text(d['message'] ?? 'No message', style: TextStyle(color: safe ? Colors.green : Colors.red)),
                  LinearProgressIndicator(value: pct, color: safe ? Colors.green : Colors.red),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(onPressed: _accessData, icon: Icon(Icons.open_in_browser), label: Text('Open')),
                  if (!safe)
                    ElevatedButton.icon(onPressed: _generatePdfReport, icon: Icon(Icons.picture_as_pdf), label: Text('Generate Report')),
                  if (pdfFile != null)
                    TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(file: pdfFile!))),
                      icon: Icon(Icons.remove_red_eye), label: Text('View Report')),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
