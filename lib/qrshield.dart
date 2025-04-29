import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';
import 'package:qrshield/resultscreen.dart';
import 'package:qrshield/screens/historyscreen.dart';
import 'package:qrshield/screens/signin_screen.dart';

const bgColor = Color.fromARGB(255, 61, 74, 165);

class Qrshield extends StatefulWidget {
  const Qrshield({Key? key}) : super(key: key);

  @override
  State<Qrshield> createState() => _QrshieldState();
}

class _QrshieldState extends State<Qrshield> {
  bool isScanCompleted = false;
  bool isFlashOn = false;
  bool isFrontCamera = false;
  final MobileScannerController controller = MobileScannerController();

  void closeScreen() {
    setState(() {
      isScanCompleted = false;
    });
  }

  void _toggleFlash() {
    setState(() {
      isFlashOn = !isFlashOn;
    });
    controller.toggleTorch();
  }

  void _switchCamera() {
    setState(() {
      isFrontCamera = !isFrontCamera;
    });
    controller.switchCamera();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              FirebaseAuth.instance.signOut().then((_) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                  (route) => false,
                );
              });
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          "QRSHIELD",
          style: TextStyle(
            fontSize: 26,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.flash_on, color: isFlashOn ? Colors.blue : Colors.grey),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Icon(Icons.switch_camera, color: isFrontCamera ? Colors.blue : Colors.grey),
            onPressed: _switchCamera,
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              "Align the QR code within the frame",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              "Scanning will start automatically",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: controller,
                    onDetect: (capture) {
                      if (!isScanCompleted) {
                        for (final barcode in capture.barcodes) {
                          final String? code = barcode.rawValue;
                          if (code != null) {
                            setState(() {
                              isScanCompleted = true;
                            });

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    Resultscreen(code: code, closeScreen: closeScreen),
                              ),
                            ).then((_) => closeScreen());
                          }
                        }
                      }
                    },
                  ),
                  QRScannerOverlay(
                    overlayColor: bgColor,
                    scanAreaSize: const Size(300, 300),
                    borderColor: Colors.white,
                    borderRadius: 12,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history),
                  label: const Text("History"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "Developed by Ali Hassan",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
