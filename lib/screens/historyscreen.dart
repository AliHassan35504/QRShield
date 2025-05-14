import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../view_pdf_screen.dart';
import '../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTimeRange? selectedDateRange;
  String filterOption = 'All';
  final _user = FirebaseAuth.instance.currentUser;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((status) {
      setState(() => _isOffline = status == ConnectivityResult.none);
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => _isOffline = result == ConnectivityResult.none);
  }

  Future<void> deleteHistory(String docId) async {
    await FirebaseFirestore.instance.collection('scanHistory').doc(docId).delete();
  }

  void _handleDataTap(BuildContext ctx, String raw, bool isSafe, String reportUrl) async {
    final urlString = raw.startsWith(RegExp(r'https?://')) ? raw : 'https://$raw';
    final uri = Uri.tryParse(urlString);
    if (uri == null || !uri.isAbsolute) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Invalid URL.")));
      return;
    }
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Cannot open the link.")));
      return;
    }
    if (isSafe) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showWarningDialog(ctx, uri.toString(), reportUrl);
    }
  }

  void _showWarningDialog(BuildContext ctx, String url, String reportUrl) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text("Warning!"),
        content: const Text("This URL has been flagged malicious. Proceed or view the report?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
          if (reportUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.of(c).pop();
                Navigator.push(context, MaterialPageRoute(builder: (_) => ViewPdfScreen(fileUrl: reportUrl)));
              },
              child: const Text("View Report"),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(c).pop();
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            child: const Text("Proceed", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDateRange = picked);
  }

  Future<void> _exportToCSV() async {
    var query = FirebaseFirestore.instance
        .collection('scanHistory')
        .where('userId', isEqualTo: _user?.uid);

    if (selectedDateRange != null) {
      final startTs = Timestamp.fromDate(selectedDateRange!.start);
      final endTs = Timestamp.fromDate(selectedDateRange!.end.add(const Duration(days: 1)));
      query = query.where('timestamp', isGreaterThanOrEqualTo: startTs, isLessThan: endTs);
    }

    final snap = await query.get();
    final rows = <List<String>>[
      ['Code', 'Type', 'Safe', 'Report', 'Timestamp'],
      ...snap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        return [
          m['code'] ?? '',
          m['type'] ?? '',
          (m['isSafe'] as bool? ?? false).toString(),
          m['reportUrl'] ?? '',
          (m['timestamp'] as Timestamp?)?.toDate().toString() ?? '',
        ];
      }),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/scan_history.csv');
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exported to ${file.path}")));
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white54, size: 60),
              const SizedBox(height: 20),
              const Text("You're offline. History is not available.", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const EntryPoint()),
                    (route) => false,
                  );
                },
                label: const Text("Return to Main Screen"),
              ),
            ],
          ),
        ),
      );
    }

    var query = FirebaseFirestore.instance
        .collection('scanHistory')
        .where('userId', isEqualTo: _user?.uid);

    if (selectedDateRange != null) {
      final startTs = Timestamp.fromDate(selectedDateRange!.start);
      final endTs = Timestamp.fromDate(selectedDateRange!.end.add(const Duration(days: 1)));
      query = query.where('timestamp', isGreaterThanOrEqualTo: startTs, isLessThan: endTs);
    }

    if (filterOption == 'Safe') {
      query = query.where('isSafe', isEqualTo: true);
    } else if (filterOption == 'Malicious') {
      query = query.where('isSafe', isEqualTo: false);
    }

    query = query.orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan History"),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDateRange),
          IconButton(icon: const Icon(Icons.download), onPressed: _exportToCSV),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Clear All History"),
                  content: const Text("Are you sure you want to delete all scan history?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete All")),
                  ],
                ),
              );
              if (confirm == true) {
                final all = await FirebaseFirestore.instance
                    .collection('scanHistory')
                    .where('userId', isEqualTo: _user?.uid)
                    .get();
                for (var d in all.docs) await d.reference.delete();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ToggleButtons(
            isSelected: [
              filterOption == 'All',
              filterOption == 'Safe',
              filterOption == 'Malicious',
            ],
            onPressed: (i) => setState(() {
              filterOption = ['All', 'Safe', 'Malicious'][i];
            }),
            children: const [
              Padding(padding: EdgeInsets.all(8), child: Text('All')),
              Padding(padding: EdgeInsets.all(8), child: Text('Safe')),
              Padding(padding: EdgeInsets.all(8), child: Text('Malicious')),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No history found."));
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, idx) {
                    final m = docs[idx].data() as Map<String, dynamic>;
                    final code = m['code'] as String? ?? '';
                    final isSafe = m['isSafe'] as bool? ?? false;
                    final type = m['type'] ?? 'Unknown';
                    final ts = (m['timestamp'] as Timestamp?)?.toDate();
                    final reportUrl = m['reportUrl'] ?? '';
                    final isOffline = m['source'] == 'offline';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          isSafe ? Icons.verified_user : Icons.warning_amber,
                          color: isSafe ? Colors.green : Colors.red,
                        ),
                        title: Text(code, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Type: $type\nTime: ${ts?.toLocal().toString() ?? "N/A"}'),
                            if (isOffline)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text("[OFFLINE]", style: TextStyle(color: Colors.orange, fontSize: 12)),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            if (!isSafe && reportUrl.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                tooltip: "View Report",
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ViewPdfScreen(fileUrl: reportUrl)),
                                  );
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Delete Entry",
                              onPressed: () => deleteHistory(docs[idx].id),
                            ),
                          ],
                        ),
                        onTap: () => _handleDataTap(context, code, isSafe, reportUrl),
                        onLongPress: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Copied to clipboard")),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
