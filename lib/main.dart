import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_options.dart';
import 'screens/signin_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'pin_setup_screen.dart';
import 'qr_scanner_widget.dart';
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
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((status) {
      setState(() => isOffline = status == ConnectivityResult.none);
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() => isOffline = result == ConnectivityResult.none);
  }

  Future<void> _handleOnlineMode() async {
    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Cannot use Online Mode.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final savedPin = await _storage.read(key: 'user_pin');

    if (user != null) {
      if (savedPin == null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PinSetupScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PinUnlockScreen()));
      }
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
    }
  }

  Future<void> _handleOfflineMode() async {
    final savedPin = await _storage.read(key: 'user_pin');
    if (savedPin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No offline user found. Please log in online once.')),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => const PinUnlockScreen()));
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _handleOnlineMode,
              child: const Text('Online Mode'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleOfflineMode,
              child: const Text('Offline Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
