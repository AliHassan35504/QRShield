class OfflineUrlChecker {
  final List<String> shorteners = [
    'bit.ly', 'goo.gl', 't.co', 'tinyurl.com', 'is.gd',
    'ow.ly', 'buff.ly', 'adf.ly', 'cutt.ly', 'shorte.st',
  ];

  final List<String> suspiciousTlds = ['.tk', '.ml', '.ga', '.cf', '.gq'];
  final List<String> sensitiveKeywords = [
    'login', 'verify', 'update', 'account', 'password',
    'click here', 'urgent', 'payment', 'reset', 'sensitive'
  ];

  final List<String> disposableDomains = [
    'mailinator.com', 'tempmail.com', '10minutemail.com', 'guerrillamail.com'
  ];

  Map<String, dynamic> analyze(String data) {
    final type = detectType(data);
    return analyzeData(data, type);
  }

  String detectType(String data) {
    final l = data.toLowerCase();
    if (l.contains('wa.me') || l.contains('api.whatsapp.com/send')) return 'WhatsApp';
    if (l.contains('forms.gle') || l.contains('docs.google.com/forms')) return 'Form';
    if (l.startsWith('http')) return 'URL';
    if (data.startsWith('WIFI:')) return 'WiFi';
    if (RegExp(r'^\+?[0-9]{6,15}$').hasMatch(data)) return 'Phone';
    if (RegExp(r'^\w+@[\w\-]+\.\w{2,4}$').hasMatch(data)) return 'Email';
    return 'Text';
  }

  // ✅ Analyze using explicit type
  Map<String, dynamic> analyzeData(String data, String type) {
    switch (type) {
      case 'URL': return _analyzeUrl(data);
      case 'WiFi': return _analyzeWifi(data);
      case 'WhatsApp': return _analyzeWhatsApp(data);
      case 'Phone': return _analyzePhone(data);
      case 'Email': return _analyzeEmail(data);
      case 'Form': return _analyzeGoogleForm(data);
      case 'Text': return _analyzeText(data);
      default:
        return {
          'type': 'Unknown',
          'triggers': ['Unknown or unsupported data type']
        };
    }
  }

  Map<String, dynamic> _analyzeUrl(String url) {
    final uri = Uri.tryParse(url);
    final bool isAbsolute = uri?.isAbsolute ?? false;
    final String scheme = uri?.scheme ?? 'unknown';
    final bool usesIp = uri != null && RegExp(r'\d+\.\d+\.\d+\.\d+').hasMatch(uri.host);
    final bool usesShortener = uri != null && shorteners.any((s) => uri.host.contains(s));
    final bool hasSuspiciousTld = uri != null && suspiciousTlds.any((tld) => uri.host.endsWith(tld));
    final bool isLong = url.length > 100;
    final bool isEncoded = url.contains('%');
    final List<String> matchedKeywords = sensitiveKeywords.where((kw) => url.toLowerCase().contains(kw)).toList();

    final List<String> triggers = [];
    if (!isAbsolute || !(scheme == 'http' || scheme == 'https')) triggers.add("Invalid or non-HTTPS URL");
    if (usesIp) triggers.add("Uses IP address instead of domain");
    if (usesShortener) triggers.add("Uses URL shortener: ${uri?.host}");
    if (hasSuspiciousTld) triggers.add("Suspicious TLD: ${uri?.host}");
    if (isLong) triggers.add("URL is excessively long");
    if (isEncoded) triggers.add("URL contains encoded characters");
    if (matchedKeywords.isNotEmpty) triggers.add("Contains sensitive keywords: ${matchedKeywords.join(', ')}");

    return {
      'type': 'URL',
      'triggers': triggers,
      'url_scheme': scheme,
      'is_absolute': isAbsolute,
      'uses_ip': usesIp,
      'uses_shortener': usesShortener,
      'suspicious_tld': hasSuspiciousTld,
      'contains_keywords': matchedKeywords,
      'is_encoded': isEncoded,
      'is_long_url': isLong,
    };
  }

  Map<String, dynamic> _analyzeWifi(String raw) {
    final details = <String, String>{};
    for (final m in RegExp(r'(S|T|P):([^;]*)').allMatches(raw)) {
      final k = m.group(1), v = m.group(2);
      if (k != null && v != null) {
        if (k == 'S') details['ssid'] = v;
        if (k == 'T') details['encryption'] = v;
        if (k == 'P') details['password'] = v;
      }
    }

    final List<String> triggers = [];
    final String ssid = details['ssid'] ?? '';
    final String encryption = (details['encryption'] ?? '').toLowerCase();
    final String password = details['password'] ?? '';

    final usesWeakEncryption = (encryption == 'wep' || encryption == 'nopass');
    final weakPassword = password.length < 8 || ['12345678', 'password'].contains(password.toLowerCase());
    final suspiciousSsid = RegExp(r'free|public|[a-z]{8,}').hasMatch(ssid.toLowerCase());

    if (usesWeakEncryption) triggers.add("Weak or no encryption ($encryption)");
    if (weakPassword) triggers.add("Weak or common password");
    if (suspiciousSsid) triggers.add("Suspicious SSID: $ssid");

    return {
      'type': 'WiFi',
      'triggers': triggers,
      'ssid': ssid,
      'encryption': encryption,
      'password': password,
      'uses_weak_encryption': usesWeakEncryption,
      'weak_password': weakPassword,
      'suspicious_ssid': suspiciousSsid,
    };
  }

  Map<String, dynamic> _analyzeWhatsApp(String raw) {
    final uri = Uri.tryParse(raw);
    final number = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.first : '';
    final message = uri?.queryParameters['text'] ?? '';
    final invalidFormat = !RegExp(r'^\+\d{6,15}$').hasMatch(number);
    final hasKeywords = sensitiveKeywords.any((k) => message.toLowerCase().contains(k));
    final triggers = <String>[];
    if (invalidFormat) triggers.add("Invalid phone number format");
    if (hasKeywords) triggers.add("Message contains suspicious keywords");

    return {
      'type': 'WhatsApp',
      'triggers': triggers,
      'number': number,
      'message': message,
      'invalid_number_format': invalidFormat,
      'message_contains_keywords': hasKeywords,
    };
  }

  Map<String, dynamic> _analyzePhone(String data) {
    final isPremium = data.startsWith('1900') || data.startsWith('900');
    final unusualPrefix = !data.startsWith('+');
    final triggers = <String>[];
    if (isPremium) triggers.add("Premium-rate number");
    if (unusualPrefix) triggers.add("Missing country code or invalid prefix");

    return {
      'type': 'Phone',
      'triggers': triggers,
      'premium_rate_number': isPremium,
      'unusual_country_code': unusualPrefix,
    };
  }

  Map<String, dynamic> _analyzeEmail(String email) {
    final valid = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(email);
    final domain = email.split('@').last;
    final isDisposable = disposableDomains.contains(domain);
    final hasKeywords = sensitiveKeywords.any((kw) => email.toLowerCase().contains(kw));
    final triggers = <String>[];
    if (!valid) triggers.add("Invalid email format");
    if (isDisposable) triggers.add("Disposable or temporary email domain: $domain");
    if (hasKeywords) triggers.add("Suspicious keywords in email");

    return {
      'type': 'Email',
      'triggers': triggers,
      'invalid_format': !valid,
      'disposable_domain': isDisposable,
      'suspicious_keywords': hasKeywords,
    };
  }

  Map<String, dynamic> _analyzeText(String text) {
    final hasPhishingWords = sensitiveKeywords.any((w) => text.toLowerCase().contains(w));
    final triggers = <String>[];
    if (hasPhishingWords) triggers.add("Text contains urgent or phishing language");

    return {
      'type': 'Text',
      'triggers': triggers,
      'contains_urgent_language': hasPhishingWords,
      'looks_like_phishing_message': hasPhishingWords,
    };
  }

  Map<String, dynamic> _analyzeGoogleForm(String url) {
    final asksSensitiveInfo = sensitiveKeywords.any((kw) => url.toLowerCase().contains(kw));
    final domainMismatch = !(url.contains('forms.gle') || url.contains('docs.google.com'));
    final triggers = <String>[];
    if (asksSensitiveInfo) triggers.add("Google Form collects sensitive info");
    if (domainMismatch) triggers.add("Unexpected Google Form host");

    return {
      'type': 'Form',
      'triggers': triggers,
      'asks_sensitive_info': asksSensitiveInfo,
      'form_host_mismatch': domainMismatch,
    };
  }
}
