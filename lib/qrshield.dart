import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';
import 'package:qrshield/resultscreen.dart';
import 'package:qrshield/screens/historyscreen.dart';
import 'package:qrshield/screens/offline_history_screen.dart';
import 'package:qrshield/screens/resultscreen_offline.dart';
import 'package:qrshield/screens/signin_screen.dart';
import 'package:qrshield/utils/offline_sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:qrshield/main.dart';

const bgColor = Color.fromARGB(255, 18, 18, 18);

class Qrshield extends StatefulWidget {
  const Qrshield({Key? key}) : super(key: key);

  @override
  State<Qrshield> createState() => _QrshieldState();
}

class _QrshieldState extends State<Qrshield> with WidgetsBindingObserver {
  bool isScanCompleted = false;
  bool isFlashOn = false;
  bool isFrontCamera = false;
  bool isOffline = false;

  final MobileScannerController controller = MobileScannerController();
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestCameraPermission();
    _checkConnectivity();

    Connectivity().onConnectivityChanged.listen((status) async {
      final connected = status != ConnectivityResult.none;
      setState(() => isOffline = !connected);
      if (connected) {
        await _syncService.syncOfflineScans();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      controller.stop();
    } else if (state == AppLifecycleState.resumed && !isScanCompleted) {
      controller.start();
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => isOffline = result == ConnectivityResult.none);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        _showPermissionDialog();
        return;
      }
    }
    await controller.start();
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Camera Permission Required"),
        content: const Text("Please enable camera permission to scan QR codes."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Open Settings"),
          ),
        ],
      ),
    );
  }

  void closeScreen() {
    setState(() {
      isScanCompleted = false;
    });
    controller.start(); // Restart scanning after closing result screen
  }

  void _toggleFlash() {
    setState(() => isFlashOn = !isFlashOn);
    controller.toggleTorch();
  }

  void _switchCamera() {
    setState(() => isFrontCamera = !isFrontCamera);
    controller.switchCamera();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
    final screen = isOffline ? const OfflineHistoryScreen() : const HistoryScreen();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _returnToMain() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const EntryPoint()),
      (route) => false,
    );
  }

  void _handleQRCode(String code) {
    if (isScanCompleted) return;
    setState(() => isScanCompleted = true);
    controller.stop();

    final screen = isOffline
        ? OfflineResultscreen(code: code, closeScreen: closeScreen)
        : Resultscreen(code: code, closeScreen: closeScreen);

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) => closeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isOffline ? Colors.red : Colors.transparent,
        elevation: 0,
        title: const Text(
          "QRSHIELD",
          style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (isOffline)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8),
                child: const Center(
                  child: Text(
                    "You are offline. Some features are unavailable.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            const Text("Align the QR code within the frame", style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 6),
            const Text("Scanning will start automatically", style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: controller,
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      if (!isScanCompleted) {
                        for (final barcode in capture.barcodes) {
                          final String? code = barcode.rawValue;
                          if (code != null) {
                            _handleQRCode(code);
                            break;
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _openHistory,
                  icon: const Icon(Icons.history),
                  label: const Text("History"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Logout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (isOffline)
                  ElevatedButton.icon(
                    onPressed: _returnToMain,
                    icon: const Icon(Icons.home),
                    label: const Text("Back to Main Screen"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Developed by Ali Hassan", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
