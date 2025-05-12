import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'qr_scanner_widget.dart';
import 'screens/signin_screen.dart';
import 'utils/color_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const QRShieldApp());
}

class QRShieldApp extends StatelessWidget {
  const QRShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRShield',
      theme: ThemeData(
        primarySwatch: MaterialColor(
          hexStringToColor("#2E7D32").value,
          {
            50: hexStringToColor("#E8F5E9"),
            100: hexStringToColor("#C8E6C9"),
            200: hexStringToColor("#A5D6A7"),
            300: hexStringToColor("#81C784"),
            400: hexStringToColor("#66BB6A"),
            500: hexStringToColor("#4CAF50"),
            600: hexStringToColor("#43A047"),
            700: hexStringToColor("#388E3C"),
            800: hexStringToColor("#2E7D32"),
            900: hexStringToColor("#1B5E20"),
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const EntryPoint(),
    );
  }
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  bool isOffline = false;
  bool showScanner = false;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then((status) {
      setState(() => isOffline = status == ConnectivityResult.none);
    });

    Connectivity().onConnectivityChanged.listen((status) {
      setState(() => isOffline = (status == ConnectivityResult.none));
    });
  }

  Future<void> _handleScan(String data) async {
    final prefs = await SharedPreferences.getInstance();
    final scanList = prefs.getStringList('offline_scans') ?? [];
    scanList.add(jsonEncode({
      'code': data,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    await prefs.setStringList('offline_scans', scanList);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR Code saved locally')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QRShield'),
        backgroundColor: isOffline ? Colors.red : null,
        actions: [
          if (isOffline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: Text("Offline Mode")),
            ),
        ],
      ),
      body: Center(
        child: showScanner
            ? QrScannerWidget(
                onScanned: (data) {
                  _handleScan(data);
                  setState(() => showScanner = false);
                },
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (isOffline) {
                        setState(() => showScanner = true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('This is only for offline usage.')),
                        );
                      }
                    },
                    child: const Text('Offline Version'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (isOffline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No internet connection. Cannot proceed to Online Version.')),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignInScreen()),
                        );
                      }
                    },
                    child: const Text('Online Version'),
                  ),
                ],
              ),
      ),
    );
  }
}
