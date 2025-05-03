class OfflineUrlChecker {
  final List<String> shorteners = [
    'bit.ly', 'goo.gl', 't.co', 'tinyurl.com', 'is.gd',
    'ow.ly', 'buff.ly', 'adf.ly', 'cutt.ly', 'shorte.st',
  ];

  final List<String> suspiciousTlds = ['.tk', '.ml', '.ga', '.cf', '.gq'];
  final List<String> keywords = ['login', 'verify', 'update', 'account', 'password'];

  bool isSuspicious(String url) => getTriggers(url).isNotEmpty;

  List<String> getTriggers(String url) {
    final List<String> triggers = [];
    final uri = Uri.tryParse(url);

    if (uri == null || !uri.isAbsolute || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      triggers.add("Invalid or non-HTTPS URL");
      return triggers;
    }

    if (url.length > 100) triggers.add("URL is excessively long");

    if (RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(uri.host)) {
      triggers.add("Uses IP address instead of domain");
    }

    if (shorteners.any((s) => uri.host.contains(s))) {
      triggers.add("Uses URL shortener: ${uri.host}");
    }

    if (suspiciousTlds.any((tld) => uri.host.endsWith(tld))) {
      triggers.add("Suspicious TLD: ${uri.host}");
    }

    if (keywords.any((kw) => url.toLowerCase().contains(kw))) {
      triggers.add("Contains sensitive keyword");
    }

    if (url.contains('%')) triggers.add("URL contains encoded characters");

    return triggers;
  }

  Map<String, dynamic> analyze(String url) {
    final uri = Uri.tryParse(url);
    final bool isAbsolute = uri?.isAbsolute ?? false;
    final String scheme = uri?.scheme ?? 'unknown';

    final bool usesIp = uri != null && RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(uri.host);
    final bool usesShortener = uri != null && shorteners.any((s) => uri.host.contains(s));
    final bool hasSuspiciousTld = uri != null && suspiciousTlds.any((tld) => uri.host.endsWith(tld));
    final List<String> matchedKeywords = keywords.where((kw) => url.toLowerCase().contains(kw)).toList();
    final bool containsEncoded = url.contains('%');
    final bool isLong = url.length > 100;

    final triggers = getTriggers(url);

    return {
      'triggers': triggers,
      'is_absolute': isAbsolute,
      'url_scheme': scheme,
      'uses_ip': usesIp,
      'uses_shortener': usesShortener,
      'suspicious_tld': hasSuspiciousTld,
      'contains_keywords': matchedKeywords,
      'is_encoded': containsEncoded,
      'is_long_url': isLong,
    };
  }
}
