import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTimeRange? selectedDateRange;
  String filterOption = 'All';
  final _user = FirebaseAuth.instance.currentUser;

  Future<void> deleteHistory(String docId) async {
    await FirebaseFirestore.instance.collection('scanHistory').doc(docId).delete();
  }

  void _handleDataTap(BuildContext ctx, String raw, bool isSafe) async {
    final urlString = raw.startsWith(RegExp(r'https?://')) ? raw : 'https://$raw';
    final uri = Uri.tryParse(urlString);
    if (uri == null || !uri.isAbsolute) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text("Invalid URL.")),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text("Cannot open the link.")),
      );
      return;
    }
    if (isSafe) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showWarningDialog(ctx, uri.toString());
    }
  }

  void _showWarningDialog(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text("Warning!"),
        content: const Text("This URL has been flagged malicious. Proceed?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text("Cancel", style: TextStyle(color: Colors.red)),
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
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDateRange = picked);
    }
  }

  Future<void> _exportToCSV() async {
    var query = FirebaseFirestore.instance
        .collection('scanHistory')
        .where('userId', isEqualTo: _user?.uid);

    if (selectedDateRange != null) {
      final startTs = Timestamp.fromDate(selectedDateRange!.start);
      final endTs = Timestamp.fromDate(
        selectedDateRange!.end.add(const Duration(days: 1)),
      );
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: startTs, isLessThan: endTs);
    }
    if (filterOption == 'Safe') {
      query = query.where('isSafe', isEqualTo: true);
    } else if (filterOption == 'Malicious') {
      query = query.where('isSafe', isEqualTo: false);
    }

    final snap = await query.get();
    final rows = <List<String>>[
      ['Code', 'Safe', 'Timestamp'],
      ...snap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        return [
          m['code'] ?? '',
          (m['isSafe'] as bool).toString(),
          m['timestamp']?.toDate().toString() ?? '',
        ];
      })
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/scan_history.csv');
    await file.writeAsString(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Exported to ${file.path}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    var query = FirebaseFirestore.instance
        .collection('scanHistory')
        .where('userId', isEqualTo: _user?.uid);

    // apply date filter
    if (selectedDateRange != null) {
      final startTs = Timestamp.fromDate(selectedDateRange!.start);
      final endTs = Timestamp.fromDate(
        selectedDateRange!.end.add(const Duration(days: 1)),
      );
      query = query
          .where('timestamp', isGreaterThanOrEqualTo: startTs, isLessThan: endTs);
    }

    // apply safety filter
    if (filterOption == 'Safe') {
      query = query.where('isSafe', isEqualTo: true);
    } else if (filterOption == 'Malicious') {
      query = query.where('isSafe', isEqualTo: false);
    }

    // order last
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
              final all = await FirebaseFirestore.instance
                  .collection('scanHistory')
                  .where('userId', isEqualTo: _user?.uid)
                  .get();
              for (var d in all.docs) await d.reference.delete();
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text("No entries found"));
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, idx) {
                    final m = docs[idx].data() as Map<String, dynamic>;
                    final code = m['code'] as String? ?? '';
                    final isSafe = m['isSafe'] as bool? ?? false;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: ListTile(
                        leading: Icon(
                          isSafe ? Icons.check_circle : Icons.warning,
                          color: isSafe ? Colors.green : Colors.red,
                        ),
                        title: Text(code),
                        subtitle: Text(m['timestamp']?.toDate().toString() ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_browser),
                              onPressed: () => _handleDataTap(context, code, isSafe),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: code));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Copied to clipboard")),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteHistory(docs[idx].id),
                            ),
                          ],
                        ),
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
