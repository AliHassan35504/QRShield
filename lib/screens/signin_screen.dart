import 'package:firebase_auth/firebase_auth.dart';
import 'package:qrshield/qrshield.dart';
import 'package:qrshield/reusable_widgets/reusable_widget.dart';
import 'package:qrshield/screens/reset_password.dart';
import 'package:qrshield/screens/signup_screen.dart';
import 'package:flutter/material.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  TextEditingController _passwordTextController = TextEditingController();
  TextEditingController _emailTextController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black54, Colors.black],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Image.asset("assets/images/qrshield.png", height: 150),
                      const SizedBox(height: 30),
                      reusableTextField("Enter Email", Icons.person_outline, false, _emailTextController),
                      const SizedBox(height: 20),
                      reusableTextField("Enter Password", Icons.lock_outline, true, _passwordTextController),
                      const SizedBox(height: 5),
                      forgetPassword(context),
                      const SizedBox(height: 20),
                      firebaseUIButton(context, "Sign In", () {
                        FirebaseAuth.instance
                            .signInWithEmailAndPassword(
                              email: _emailTextController.text.trim(),
                              password: _passwordTextController.text.trim(),
                            )
                            .then((value) {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Qrshield()));
                        }).catchError((error) {
                          String errorMessage = "An error occurred, please try again.";
                          if (error is FirebaseAuthException) {
                            if (error.code == 'user-not-found') {
                              errorMessage = "No user found for that email.";
                            } else if (error.code == 'wrong-password') {
                              errorMessage = "Incorrect password.";
                            }
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                            ),
                          );
                        });
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              signUpOption(), // Now Sign Up option placed OUTSIDE scroll
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Row signUpOption() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account?",
          style: TextStyle(color: Colors.white70),
        ),
        InkWell(
          onTap: () {
            print("Sign Up Text Pressed!");
            Navigator.push(context, MaterialPageRoute(builder: (context) => SignUpScreen()));
          },
          child: const Text(
            " Sign Up",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget forgetPassword(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ResetPassword()));
        },
        child: const Text(
          "Forgot Password?",
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
