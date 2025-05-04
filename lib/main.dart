import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'firebase_options.dart';
import 'qr_scanner_widget.dart';
import 'package:qrshield/screens/signin_screen.dart';
import 'package:qrshield/qrshield.dart';
import 'utils/color_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
          <int, Color>{
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
      home: const EntryPoint(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class EntryPoint extends StatefulWidget {
  const EntryPoint({super.key});

  @override
  State<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends State<EntryPoint> {
  bool _loading = true;
  bool _hasInternet = false;

  @override
  void initState() {
    super.initState();
    _checkStartupConditions();
  }

  Future<void> _checkStartupConditions() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet = connectivity != ConnectivityResult.none;
    final user = FirebaseAuth.instance.currentUser;

    setState(() {
      _hasInternet = hasInternet;
    });

    if (user != null && hasInternet) {
      // Online and logged in
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Qrshield()));
    } else if (user != null && !hasInternet) {
      // Offline but previously signed in
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Qrshield()));
    } else if (!hasInternet) {
      // Offline and not logged in
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OfflineScanOnlyScreen()));
    } else {
      // Online but not signed in
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : const Text("Redirecting...", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class OfflineScanOnlyScreen extends StatelessWidget {
  const OfflineScanOnlyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Offline Scan Mode")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("You're offline. Sign in disabled.", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            QrScannerWidget(
              onScanned: (code) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Scanned: $code")));
                // Offline scan handling
              },
            ),
          ],
        ),
      ),
    );
  }
}
