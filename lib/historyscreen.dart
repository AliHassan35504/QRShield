import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  Future<void> deleteHistory(String docId) async {
    await FirebaseFirestore.instance.collection('scanHistory').doc(docId).delete();
  }

  // 🔹 Open URL based on safety status
  void _handleUrlTap(BuildContext context, String url, bool isSafe) async {
    if (isSafe) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cannot open the URL.")),
        );
      }
    } else {
      _showWarningDialog(context, url);
    }
  }

  // 🔹 Show a warning dialog for malicious URLs
  void _showWarningDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Warning!"),
        content: Text("This URL has been flagged as malicious. Proceed with caution."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              }
            },
            child: Text("Proceed", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Scan History"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () async {
              final history = await FirebaseFirestore.instance.collection('scanHistory')
                  .where('userId', isEqualTo: user?.uid).get();

              for (var doc in history.docs) {
                await doc.reference.delete();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('scanHistory')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No scan history found."));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: Icon(
                  data['isSafe'] ? Icons.check_circle : Icons.warning,
                  color: data['isSafe'] ? Colors.green : Colors.red,
                ),
                title: Text(data['code']),
                subtitle: Text(data['timestamp']?.toDate().toString() ?? 'Unknown Time'),
                trailing: IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => deleteHistory(doc.id),
                ),
                onTap: () => _handleUrlTap(context, data['code'], data['isSafe']),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
