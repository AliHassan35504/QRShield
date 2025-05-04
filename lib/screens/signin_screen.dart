import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:qrshield/qrshield.dart';
import 'package:qrshield/screens/reset_password.dart';
import 'package:qrshield/screens/signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((status) {
      setState(() {
        _isOffline = status == ConnectivityResult.none;
      });
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildContent(),
            if (_isOffline)
              Container(
                width: double.infinity,
                color: Colors.redAccent,
                padding: const EdgeInsets.all(8),
                child: const Center(
                  child: Text("You're offline. Some features are disabled.",
                      style: TextStyle(color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
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

          // Email
          TextField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Email", Icons.email),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),

          // Password
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
              onPressed: _isOffline
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPassword())),
              child: const Text("Forgot Password?", style: TextStyle(color: Colors.white70)),
            ),
          ),

          const SizedBox(height: 20),

          // Sign In Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isOffline ? _showOfflineWarning : _signIn,
              child: const Text("Sign In", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
              TextButton(
                onPressed: _isOffline
                    ? _showOfflineWarning
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                child: const Text("Sign Up",
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
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

  void _showOfflineWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No internet connection.")),
    );
  }

  void _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please fill all fields");
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Qrshield()));
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
