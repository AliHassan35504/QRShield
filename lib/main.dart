import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_options.dart';
import 'screens/signin_screen.dart';
import 'screens/pin_setup_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'utils/color_utils.dart';
import 'utils/offline_sync_service.dart';
import 'utils/urlhaus_blacklist_loader.dart';

late UrlHausBlacklistLoader blacklistLoader;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load URLHaus blacklist from assets
  blacklistLoader = UrlHausBlacklistLoader();
  await blacklistLoader.loadFromAssets();

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
  final OfflineSyncService _syncService = OfflineSyncService();

  @override
  void initState() {
    super.initState();
    _checkConnectivity();

    Connectivity().onConnectivityChanged.listen((status) async {
      final nowOffline = status == ConnectivityResult.none;
      setState(() => isOffline = nowOffline);

      if (!nowOffline) {
        await _syncService.syncOfflineScans(); // Trigger sync on reconnect
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final nowOffline = result == ConnectivityResult.none;
    setState(() => isOffline = nowOffline);

    if (!nowOffline) {
      await _syncService.syncOfflineScans(); // Also sync on app start if online
    }
  }

  void _handleOnlineMode() {
    if (isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet connection. Cannot use Online Mode.')),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SignInScreen()));
  }

  void _handleOfflineMode() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineLoginScreen()));
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

class OfflineLoginScreen extends StatefulWidget {
  const OfflineLoginScreen({Key? key}) : super(key: key);

  @override
  State<OfflineLoginScreen> createState() => _OfflineLoginScreenState();
}

class _OfflineLoginScreenState extends State<OfflineLoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final _storage = const FlutterSecureStorage();

  void _attemptLogin() async {
    final email = _email.text.trim().toLowerCase();
    final password = _password.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Enter email and password.");
      return;
    }

    final storedEmail = await _storage.read(key: 'email');
    final storedPassword = await _storage.read(key: 'password');

    if (storedEmail == email && storedPassword == password) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PinUnlockScreen(email: email),
        ),
      );
    } else {
      _showSnack("Invalid credentials. Try again or log in online first.");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Offline Login")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Enter your credentials to unlock QRShield offline."),
            const SizedBox(height: 20),
            TextField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              onPressed: _attemptLogin,
              label: const Text("Continue to PIN"),
            ),
          ],
        ),
      ),
    );
  }
}
