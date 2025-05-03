// Updated url_safety_checker.dart with full structured reporting and section-based scoring

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'offline_url_checker.dart';

class UrlSafetyChecker {
  final String googleApiKey = 'AIzaSyC8-mv2cdIAhuzQWskgnVQQ-B0WrNWUudA';
  final String virusTotalApiKey = '067ec63099db4bcc535600a30dcb1e7e8a2eb97035b789162f7b70919f3e07b8';
  final String ipQualityApiKey = 'MxGyX2vpTpdllWUYAF6gDtGcjWvIuDGo';
  final String urlscanApiKey = '01969327-d26c-72d9-a9dc-8b1db40b27e4';

  final OfflineUrlChecker offlineChecker = OfflineUrlChecker();

  Future<Map<String, dynamic>> checkFullReport(String url) async {
    final result = <String, dynamic>{};
    double totalScore = 0.0;

    // Heuristic Check
    final heur = offlineChecker.analyze(url);
    final heurScore = heur['triggers'].isNotEmpty ? 20.0 : 0.0;
    totalScore += heurScore;
    result['heuristic'] = heur;

    // Google Safe Browsing
    final google = await _checkWithGoogleSafeBrowsing(url);
    final googleScore = google['matches'].isNotEmpty ? 20.0 : 0.0;
    totalScore += googleScore;
    result['google_safe'] = google['isSafe'];
    result['google_matches'] = google['matches'];
    result['google_message'] = google['message'];

    // VirusTotal
    final vt = await _checkWithVirusTotal(url);
    final vtScore = vt['malicious'] + vt['suspicious'] > 0 ? 30.0 : 0.0;
    totalScore += vtScore;
    result['vt_safe'] = vt['isSafe'];
    result['vt_malicious'] = vt['malicious'];
    result['vt_suspicious'] = vt['suspicious'];
    result['vt_total'] = vt['total'];
    result['vt_message'] = vt['message'];

    // OpenPhish
    final op = await _checkWithPhishTank(url);
    final phishScore = !op['isSafe'] ? 10.0 : 0.0;
    totalScore += phishScore;
    result['phish_safe'] = op['isSafe'];
    result['phish_message'] = op['message'];

    // IPQualityScore
    final ipq = await _checkWithIPQualityScore(url);
    final ipqScore = ipq['risk_score'] >= 75 ? 20.0 : (ipq['risk_score'] >= 40 ? 10.0 : 0.0);
    totalScore += ipqScore;
    result['ipq'] = ipq;

    // urlscan.io
    final scan = await _checkWithUrlScan(url);
    result['scan_status'] = scan['status'];
    result['scan_result'] = scan['result_url'];
    result['scan_screenshot'] = scan['screenshot_url'];

    final isSafe = totalScore < 50.0;
    result['final_score'] = totalScore;
    result['isSafe'] = isSafe;
    result['finalVerdict'] = isSafe
        ? '✅ Safe — Passed all major checks.'
        : '❌ Malicious — Fails one or more safety checks.';

    return result;
  }

  Future<Map<String, dynamic>> _checkWithGoogleSafeBrowsing(String url) async {
    final apiUrl = 'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$googleApiKey';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client': {'clientId': 'qrshield', 'clientVersion': '1.0.0'},
        'threatInfo': {
          'threatTypes': [
            'MALWARE', 'SOCIAL_ENGINEERING',
            'POTENTIALLY_HARMFUL_APPLICATION', 'UNWANTED_SOFTWARE'
          ],
          'platformTypes': ['ANY_PLATFORM'],
          'threatEntryTypes': ['URL'],
          'threatEntries': [{'url': url}],
        },
      }),
    );
    final data = jsonDecode(response.body);
    final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
    return {
      'isSafe': matches.isEmpty,
      'matches': matches.map((m) => m['threatType']).toList(),
      'message': matches.isEmpty ? 'No threats found.' : 'Google flagged this as potentially harmful.'
    };
  }

  Future<Map<String, dynamic>> _checkWithVirusTotal(String url) async {
    final encoded = base64Url.encode(utf8.encode(url)).replaceAll('=', '');
    final uri = Uri.parse('https://www.virustotal.com/api/v3/urls/$encoded');
    final response = await http.get(uri, headers: {'x-apikey': virusTotalApiKey});
    final data = jsonDecode(response.body);
    final stats = data['data']['attributes']['last_analysis_stats'] ?? {};
    return {
      'isSafe': (stats['malicious'] ?? 0) == 0 && (stats['suspicious'] ?? 0) == 0,
      'malicious': stats['malicious'] ?? 0,
      'suspicious': stats['suspicious'] ?? 0,
      'total': (stats['harmless'] ?? 0) + (stats['malicious'] ?? 0) + (stats['suspicious'] ?? 0),
      'message': '${stats['malicious']} malicious, ${stats['suspicious']} suspicious engines.'
    };
  }

  Future<Map<String, dynamic>> _checkWithPhishTank(String url) async {
    try {
      final resp = await http.get(Uri.parse('https://openphish.com/feed.txt'));
      final lines = resp.body.split('\n');
      final found = lines.any((line) => url.contains(line.trim()));
      return {
        'isSafe': !found,
        'message': found ? 'URL is listed in OpenPhish phishing feed.' : 'Not found in OpenPhish feed.'
      };
    } catch (_) {
      return {
        'isSafe': true,
        'message': 'OpenPhish check skipped.'
      };
    }
  }

  Future<Map<String, dynamic>> _checkWithIPQualityScore(String url) async {
    final uri = Uri.parse('https://ipqualityscore.com/api/json/url/$ipQualityApiKey/${Uri.encodeComponent(url)}');
    final response = await http.get(uri);
    final data = jsonDecode(response.body);
    return {
      'risk_score': data['risk_score'] ?? 0,
      'malware': data['malware'] ?? false,
      'phishing': data['phishing'] ?? false,
      'domain_rank': data['domain_rank'] ?? 0,
      'spamming': data['spamming'] ?? false,
      'suspicious': data['suspicious'] ?? false,
      'message': 'Risk: ${data['risk_score']}, Malware: ${data['malware']}, Phishing: ${data['phishing']}'
    };
  }

  Future<Map<String, dynamic>> _checkWithUrlScan(String url) async {
    try {
      final result = await http.post(
        Uri.parse('https://urlscan.io/api/v1/scan/'),
        headers: {
          'Content-Type': 'application/json',
          'API-Key': urlscanApiKey,
        },
        body: jsonEncode({'url': url, 'visibility': 'unlisted'}),
      );
      final data = jsonDecode(result.body);
      return {
        'status': 'Completed',
        'result_url': 'https://urlscan.io/result/${data['uuid']}/',
        'screenshot_url': data['screenshot'] ?? ''
      };
    } catch (_) {
      return {
        'status': 'Error',
        'result_url': '',
        'screenshot_url': ''
      };
    }
  }
} 
