import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:qrshield/screens/signin_screen.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
 
theme: ThemeData(
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0.0,
  )
), 

      home: SignInScreen(),
      debugShowCheckedModeBanner: false,
      title: 'QRSHIELD',

    );
  }
}

