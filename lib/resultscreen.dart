import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // For copying to clipboard
import 'package:qr_flutter/qr_flutter.dart';
import 'url_safety_checker.dart';  // Import the URL checker class

class Resultscreen extends StatefulWidget {
  final String code;
  final Function() closeScreen;

  const Resultscreen({super.key, required this.closeScreen, required this.code});

  @override
  _ResultscreenState createState() => _ResultscreenState();
}

class _ResultscreenState extends State<Resultscreen> {
  late Future<Map<String, dynamic>> urlSafetyCheck;

  @override
  void initState() {
    super.initState();
    // Start the URL safety check immediately after widget is initialized
    urlSafetyCheck = UrlSafetyChecker().checkUrlSafety(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            widget.closeScreen();
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
        ),
        centerTitle: true,
        title: const Text(
          "QR Scanner",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: Container(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              QrImageView(
                data: widget.code,
                size: 150,
                version: QrVersions.auto,
              ),
              const SizedBox(height: 20),
              Text(
                "Scanned Result",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              // Use FutureBuilder to check the URL safety asynchronously
              FutureBuilder<Map<String, dynamic>>(
                future: urlSafetyCheck,
                builder: (context, snapshot) {
                  // Show loading indicator while waiting for result
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text("Error: ${snapshot.error}");
                  }

                  final result = snapshot.data;
                  if (result != null) {
                    return Column(
                      children: [
                        // Display whether the URL is safe or malicious
                        Text(
                          result["message"], // Display the safety message
                          style: TextStyle(
                            fontSize: 16,
                            color: result["isSafe"] ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        // Button to copy the URL to clipboard
                        ElevatedButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("URL copied to clipboard")));
                          },
                          child: Text("Copy URL"),
                        ),
                      ],
                    );
                  } else {
                    return Text("Error checking URL safety.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
