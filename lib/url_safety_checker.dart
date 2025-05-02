import 'dart:convert';
import 'package:http/http.dart' as http;
import 'offline_url_checker.dart';

class UrlSafetyChecker {
  final String googleApiKey = 'AIzaSyC8-mv2cdIAhuzQWskgnVQQ-B0WrNWUudA';
  final String virusTotalApiKey = '067ec63099db4bcc535600a30dcb1e7e8a2eb97035b789162f7b70919f3e07b8';
  final String ipQualityApiKey = 'MxGyX2vpTpdllWUYAF6gDtGcjWvIuDGo';
  final String urlscanApiKey = '01969327-d26c-72d9-a9dc-8b1db40b27e4';
final OfflineUrlChecker offlineChecker = OfflineUrlChecker();

  /// Unified full safety check
  Future<Map<String, dynamic>> checkUrlSafety(String url) async {
    if (offlineChecker.isSuspicious(url)) {
      return {
        'isSafe': false,
        'source': 'Offline Heuristic',
        'message': 'URL failed offline safety check',
        'details': offlineChecker.getTriggers(url),
      };
    }

    final google = await _checkWithGoogleSafeBrowsing(url);
    if (!google['isSafe']) return {...google, 'source': 'Google Safe Browsing'};

    final virusTotal = await _checkWithVirusTotal(url);
    if (!virusTotal['isSafe']) return {...virusTotal, 'source': 'VirusTotal'};

    final openPhish = await _checkWithPhishTank(url);
    if (!openPhish['isSafe']) return {...openPhish, 'source': 'OpenPhish'};

    final ipQuality = await _checkWithIPQualityScore(url);
    if (!ipQuality['isSafe']) return {...ipQuality, 'source': 'IPQualityScore'};

    final urlscan = await _checkWithUrlScan(url);
    if (!urlscan['isSafe']) return {...urlscan, 'source': 'urlscan.io'};

    return {
      'isSafe': true,
      'source': 'All',
      'message': 'URL passed all safety checks.',
      'details': <String>[],
    };
  }

  /// Individual API calls
  Future<Map<String, dynamic>> googleCheck(String url) => _checkWithGoogleSafeBrowsing(url);
  Future<Map<String, dynamic>> virusTotalCheck(String url) => _checkWithVirusTotal(url);
  Future<Map<String, dynamic>> openPhishCheck(String url) => _checkWithPhishTank(url);
  Future<Map<String, dynamic>> checkWithIPQualityScore(String url) => _checkWithIPQualityScore(url);
  Future<Map<String, dynamic>> checkWithUrlScan(String url) => _checkWithUrlScan(url);

  Future<Map<String, dynamic>> _checkWithGoogleSafeBrowsing(String url) async {
    final apiUrl = 'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$googleApiKey';
    final body = jsonEncode({
      'client': {'clientId': 'qrshield', 'clientVersion': '1.0.0'},
      'threatInfo': {
        'threatTypes': [
          'MALWARE', 'SOCIAL_ENGINEERING',
          'POTENTIALLY_HARMFUL_APPLICATION', 'UNWANTED_SOFTWARE'
        ],
        'platformTypes': ['ANY_PLATFORM'],
        'threatEntryTypes': ['URL'],
        'threatEntries': [{'url': url}]
      }
    });

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Google API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final matches = data['matches'] as List<dynamic>?;

    return {
      'isSafe': matches == null || matches.isEmpty,
      'message': matches == null || matches.isEmpty
          ? 'No threats found.'
          : 'Threat detected!',
    };
  }

  Future<Map<String, dynamic>> _checkWithVirusTotal(String url) async {
    final encoded = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    final uri = Uri.parse('https://www.virustotal.com/api/v3/urls/$encoded');

    final response = await http.get(uri, headers: {'x-apikey': virusTotalApiKey});
    if (response.statusCode != 200) {
      throw Exception('VirusTotal API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final stats = data['data']['attributes']['last_analysis_stats'] ?? {};
    final malicious = stats['malicious'] ?? 0;
    final suspicious = stats['suspicious'] ?? 0;

    final isSafe = malicious == 0 && suspicious == 0;
    return {
      'isSafe': isSafe,
      'message': isSafe
          ? 'No malicious engines flagged it.'
          : '$malicious malicious, $suspicious suspicious engines.',
    };
  }

  Future<Map<String, dynamic>> _checkWithPhishTank(String url) async {
    try {
      final resp = await http.get(Uri.parse('https://openphish.com/feed.txt'));
      if (resp.statusCode != 200) throw Exception('OpenPhish feed unreachable');

      final lines = resp.body.split('\n');
      final isPhish = lines.any((line) => line.isNotEmpty && url.contains(line.trim()));

      return {
        'isSafe': !isPhish,
        'message': isPhish
            ? 'Listed in OpenPhish feed.'
            : 'Not found in OpenPhish feed.',
      };
    } catch (_) {
      return {
        'isSafe': true,
        'message': 'OpenPhish check skipped.',
      };
    }
  }

  Future<Map<String, dynamic>> _checkWithIPQualityScore(String url) async {
    final encodedUrl = Uri.encodeComponent(url);
    final uri = Uri.parse(
      'https://ipqualityscore.com/api/json/url/$ipQualityApiKey/$encodedUrl'
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('IPQualityScore API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return {
      'isSafe': !(data['malware'] == true || data['phishing'] == true),
      'message': 'IPQualityScore → Risk: ${data['risk_score']}, Malware: ${data['malware']}, Phishing: ${data['phishing']}'
    };
  }

  Future<Map<String, dynamic>> _checkWithUrlScan(String url) async {
    final scanUri = Uri.parse('https://urlscan.io/api/v1/scan/');
    final result = await http.post(
      scanUri,
      headers: {
        'Content-Type': 'application/json',
        'API-Key': urlscanApiKey,
      },
      body: jsonEncode({'url': url, 'visibility': 'unlisted'}),
    );

    if (result.statusCode != 200) {
      throw Exception('urlscan.io scan failed');
    }

    final data = jsonDecode(result.body);
    final uuid = data['uuid'];
    final resultUrl = 'https://urlscan.io/result/$uuid/';
    final screenshotUrl = data['screenshot'] ?? '';

    return {
      'isSafe': true,
      'message': 'urlscan.io scan completed',
      'details': ['Result URL: $resultUrl', 'Screenshot: $screenshotUrl'],
    };
  }
}