import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';
import 'package:qrshield/historyscreen.dart';
import 'package:qrshield/resultscreen.dart';
import 'package:qrshield/screens/signin_screen.dart';
import 'package:qrshield/url_safety_checker.dart';

const bgColor = Color.fromARGB(255, 61, 74, 165);

class Qrshield extends StatefulWidget {
  const Qrshield({super.key});

  @override
  State<Qrshield> createState() => _QrshieldState();
}

class _QrshieldState extends State<Qrshield> {
  bool isScanCompleted = false;
  MobileScannerController controller = MobileScannerController();

  void closeScreen() {
    setState(() {
      isScanCompleted = false;
    });
  }

  // 🔹 Save Scan History to Firestore
  Future<void> saveScanHistory(String code, bool isSafe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('scanHistory').add({
        'userId': user.uid,
        'code': code,
        'isSafe': isSafe,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HistoryScreen()), // Open History Page
            ),
            icon: Icon(Icons.history, size: 25, color: Colors.white),
          ),
          IconButton(
            onPressed: () {
              FirebaseAuth.instance.signOut().then((value) {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (context) => SignInScreen()));
              });
            },
            icon: Icon(Icons.logout, size: 25, color: Colors.white),
          ),
        ],
        centerTitle: true,
        title: const Text(
          "QRSHIELD",
          style: TextStyle(fontSize: 35, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (BarcodeCapture capture) {
              if (!isScanCompleted) {
                for (final barcode in capture.barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null) {
                    setState(() {
                      isScanCompleted = true;
                    });

                    // Call URL Safety Checker
                    UrlSafetyChecker().checkUrlSafety(code).then((result) {
                      bool isSafe = result['isSafe'];
                      saveScanHistory(code, isSafe); // Save scan to history

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Resultscreen(closeScreen: closeScreen, code: code),
                        ),
                      ).then((_) => closeScreen());
                    });
                  }
                }
              }
            },
          ),
          QRScannerOverlay(
            overlayColor: bgColor,
            scanAreaSize: Size(350, 350),
            borderColor: Colors.white,
            borderRadius: 10,
            borderStrokeWidth: 4,
          ),
        ],
      ),
    );
  }
}
