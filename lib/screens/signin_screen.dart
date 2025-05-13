import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:qrshield/screens/pin_unlock_screen.dart';
import 'package:qrshield/screens/pin_setup_screen.dart';
import 'package:qrshield/screens/reset_password.dart';
import 'package:qrshield/screens/signup_screen.dart';
import 'package:qrshield/screens/pin_reset_screen.dart';
import '../main.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _obscurePassword = true;
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

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "No internet connection.\nPlease go back or try again later.",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const EntryPoint()),
                      (route) => false,
                    );
                  },
                  child: const Text("Return to Main Screen"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              Image.asset("assets/images/qrshield.png", height: 150),
              const SizedBox(height: 30),
              const Text("Welcome Back",
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Email", Icons.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Password", Icons.lock).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white70,
                    ),
                    onPressed: _togglePasswordVisibility,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPassword())),
                  child: const Text("Forgot Password?", style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _signIn,
                  child: const Text("Sign In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PinResetScreen()));
                },
                child: const Text("Forgot PIN?", style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen()));
                    },
                    child: const Text("Sign Up", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(12),
      ),
      fillColor: Colors.white10,
      filled: true,
    );
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please fill all fields");
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);

      // Save credentials to secure local storage
      await _storage.write(key: 'email', value: email);
      await _storage.write(key: 'password', value: password);

      // Check if a PIN exists for this email
      final pinKey = 'pin_$email';
      final savedPin = await _storage.read(key: pinKey);

      // Clean up legacy key if exists
      await _storage.delete(key: 'user_pin');

      if (savedPin != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PinUnlockScreen(email: email, password: password)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String error = "Login failed";
      if (e.code == 'user-not-found') error = "No user found for that email.";
      if (e.code == 'wrong-password') error = "Incorrect password.";
      _showSnack(error);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
