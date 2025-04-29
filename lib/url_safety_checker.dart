import 'dart:convert';
import 'package:http/http.dart' as http;

class UrlSafetyChecker {
  final String apiKey = 'AIzaSyC8-mv2cdIAhuzQWskgnVQQ-B0WrNWUudA';  
// List of common URL shortening services
  final List<String> shorteners = ['bit.ly', 'goo.gl', 't.co', 'tinyurl.com', 'is.gd'];

  // Method to check URL safety
  Future<Map<String, dynamic>> checkUrlSafety(String url) async {
    final String apiUrl =
        'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$apiKey';

    final Map<String, dynamic> requestBody = {
      "client": {
        "clientId": "flutter",
        "clientVersion": "1.0.0"
      },
      "threatInfo": {
        "threatTypes": [
          "MALWARE",
          "SOCIAL_ENGINEERING",
          "POTENTIALLY_HARMFUL_APPLICATION",
          "UNWANTED_SOFTWARE"
        ],
        "platformTypes": ["ANY_PLATFORM"],
        "threatEntryTypes": ["URL"],
        "threatEntries": [
          {
            "url": url,
          },
        ],
      }
    };

    try {
      // Check if the URL is from a common shortener or suspicious domain first
      if (_isSuspicious(url)) {
        return {"isSafe": false, "message": "This URL is suspicious (shortened or potentially fake)."};
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Check if the URL is found in the response matches list
        if (responseData.containsKey('matches') && responseData['matches'].isNotEmpty) {
          return {"isSafe": false, "message": "This URL is malicious."};
        } else {
          return {"isSafe": true, "message": "This URL is safe."};
        }
      } else {
        throw Exception('Failed to check URL safety. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      return {"isSafe": false, "message": "Error occurred: $error"};
    }
  }

  // Method to check if the URL is suspicious or shortened
  bool _isSuspicious(String url) {
    // Check if the URL contains any of the known URL shorteners
    for (var shortener in shorteners) {
      if (url.contains(shortener)) {
        return true;  // Return true if a shortened URL is found
      }
    }

    // Regular expression to check for common patterns in fake or temporary URLs
    final fakeUrlPattern = RegExp(r'^(http(s)?://)?([a-zA-Z0-9-]+(\.[a-zA-Z]{2,}){1,})');
    final isValidUrl = fakeUrlPattern.hasMatch(url);

    if (!isValidUrl) {
      return true; // If URL doesn't match common valid patterns, flag it
    }

    return false; // URL seems fine if not flagged above
  }
}