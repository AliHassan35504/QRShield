import 'dart:convert';
import 'package:http/http.dart' as http;
import 'offline_url_checker.dart';

class UrlSafetyChecker {
  final String googleApiKey = 'AIzaSyC8-mv2cdIAhuzQWskgnVQQ-B0WrNWUudA'; // Replace with your own
  final String virusTotalApiKey = '067ec63099db4bcc535600a30dcb1e7e8a2eb97035b789162f7b70919f3e07b8'; // Replace with your own

  final OfflineUrlChecker offlineChecker = OfflineUrlChecker();

  Future<Map<String, dynamic>> checkUrlSafety(String url) async {
    try {
      // Step 1: Basic offline heuristic check
      if (offlineChecker.isSuspicious(url)) {
        return {
          "isSafe": false,
          "message": "Offline check: URL looks suspicious or malformed.",
        };
      }

      // Step 2: Google Safe Browsing
      final googleResult = await _checkWithGoogleSafeBrowsing(url);
      if (!googleResult["isSafe"]) return googleResult;

      // Step 3: VirusTotal
      final virusTotalResult = await _checkWithVirusTotal(url);
      if (!virusTotalResult["isSafe"]) return virusTotalResult;

      // Step 4: PhishTank / OpenPhish fallback
      final phishResult = await _checkWithPhishTank(url);
      if (!phishResult["isSafe"]) return phishResult;

      return {"isSafe": true, "message": "URL passed all safety checks."};
    } catch (e) {
      return {
        "isSafe": false,
        "message": "Error during URL safety check: ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> _checkWithGoogleSafeBrowsing(String url) async {
    final apiUrl =
        'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$googleApiKey';

    final Map<String, dynamic> requestBody = {
      "client": {
        "clientId": "qrshield",
        "clientVersion": "1.0.0",
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
          {"url": url}
        ],
      },
    };

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data.containsKey('matches')) {
        return {
          "isSafe": false,
          "message": "Google Safe Browsing: Threat detected!",
        };
      }
      return {"isSafe": true, "message": "Google Safe Browsing: No threats found."};
    } else {
      throw Exception("Google API error: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> _checkWithVirusTotal(String url) async {
    final encodedUrl = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    final uri = Uri.parse("https://www.virustotal.com/api/v3/urls/$encodedUrl");

    final response = await http.get(uri, headers: {
      'x-apikey': virusTotalApiKey,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final stats = data['data']['attributes']['last_analysis_stats'];

      if ((stats['malicious'] ?? 0) > 0 || (stats['suspicious'] ?? 0) > 0) {
        return {
          "isSafe": false,
          "message": "VirusTotal: Detected as malicious/suspicious.",
        };
      }
      return {"isSafe": true, "message": "VirusTotal: No issues found."};
    } else {
      throw Exception("VirusTotal API error: ${response.statusCode}");
    }
  }

  Future<Map<String, dynamic>> _checkWithPhishTank(String url) async {
    try {
      // Since PhishTank official API is outdated, we use OpenPhish raw feed for URL matching
      final response = await http.get(
        Uri.parse("https://openphish.com/feed.txt"),
      );

      if (response.statusCode == 200) {
        final List<String> urls = response.body.split('\n');
        final isPhishing = urls.any((phishUrl) => url.contains(phishUrl.trim()));
        if (isPhishing) {
          return {
            "isSafe": false,
            "message": "OpenPhish: URL is listed in phishing database.",
          };
        } else {
          return {
            "isSafe": true,
            "message": "OpenPhish: URL not found in database.",
          };
        }
      } else {
        throw Exception("OpenPhish feed unreachable");
      }
    } catch (_) {
      return {
        "isSafe": true,
        "message": "OpenPhish check skipped (offline or error).",
      };
    }
  }
}
