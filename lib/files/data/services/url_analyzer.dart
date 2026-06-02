// lib/data/services/url_analyzer.dart

import 'dart:math';
import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';

const _shortenerDomains = {
  'bit.ly', 'tinyurl.com', 't.co', 'goo.gl', 'ow.ly', 'is.gd',
  'buff.ly', 'adf.ly', 'short.link', 'rebrand.ly', 'cutt.ly',
  'shorturl.at', 'tiny.cc', 'clck.ru', 'snip.ly',
};

const _suspiciousTlds = {
  'xyz', 'top', 'click', 'gq', 'tk', 'ml', 'cf'
};

const _trustedDomains = {
  'google.com',
  'paypal.com',
  'amazon.com',
  'microsoft.com',
  'apple.com',
  'facebook.com',
};

const _suspiciousKeywords = [
  'secure', 'update', 'urgent', 'verify', 'confirm',
  'validate', 'free', 'prize', 'winner', 'claim', 'alert',
  'suspended', 'limited', 'expire', 'immediately',
];

final _ipv4Regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

class UrlAnalyzerService {

  UrlAnalysis analyze(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);

    if (uri == null || !uri.hasScheme) {
      return _empty(rawUrl);
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();
    final fullLower = rawUrl.toLowerCase();

    final rootDomain = _extractRootDomain(host);

    final foundSuspicious = _suspiciousKeywords
        .where((kw) => fullLower.contains(kw))
        .toList();

    return UrlAnalysis(
      rawUrl: rawUrl,
      scheme: uri.scheme,
      domain: host,
      path: uri.path,
      queryParams: uri.queryParameters,

      isHttps: uri.scheme == 'https',
      isIpBased: _ipv4Regex.hasMatch(host),
      isShortener: _shortenerDomains.contains(host),
      hasPunycode: host.contains('xn--'),

      isLookalikeDomain: _isLookalike(rootDomain),
      hasSuspiciousTld: _hasSuspiciousTld(host),
      hasExcessiveSubdomains: host.split('.').length > 3,
      domainEntropy: _entropy(host),

      suspiciousKeywords: foundSuspicious,
      intent: _classifyIntent(path, query, fullLower),
    );
  }

  UrlAnalysis _empty(String raw) {
    return UrlAnalysis(
      rawUrl: raw,
      scheme: '',
      domain: raw,
      path: '',
      queryParams: {},
      isHttps: false,
      isIpBased: false,
      isShortener: false,
      hasPunycode: false,
      suspiciousKeywords: [],
      intent: IntentType.unknown,
    );
  }

  // DOMAIN LOGIC

  String _extractRootDomain(String host) {
    final parts = host.split('.');
    if (parts.length < 2) return host;
    return '${parts[parts.length - 2]}.${parts.last}';
  }

  bool _hasSuspiciousTld(String host) {
    final tld = host.split('.').last;
    return _suspiciousTlds.contains(tld);
  }

  bool _isLookalike(String domain) {
    for (final trusted in _trustedDomains) {
      final dist = _levenshtein(domain, trusted);
      if (dist > 0 && dist <= 2) return true;
    }
    return false;
  }

  // ENTROPY

  double _entropy(String input) {
    final freq = <String, int>{};

    for (var c in input.split('')) {
      freq[c] = (freq[c] ?? 0) + 1;
    }

    double entropy = 0;
    final len = input.length;

    for (var count in freq.values) {
      final p = count / len;
      entropy -= p * (log(p) / log(2));
    }

    return entropy;
  }

  // INTENT

  IntentType _classifyIntent(String path, String query, String fullUrl) {
    final s = '$path$query$fullUrl';

    if (s.contains('login') || s.contains('auth')) {
      return IntentType.login;
    }
    if (s.contains('pay') || s.contains('checkout')) {
      return IntentType.payment;
    }
    if (s.contains('download') || s.contains('.apk')) {
      return IntentType.download;
    }

    return IntentType.navigation;
  }

  // LEVENSHTEIN

  int _levenshtein(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
          (_) => List.filled(b.length + 1, 0),
    );

    for (var i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (var j = 0; j <= b.length; j++) matrix[0][j] = j;

    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;

        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return matrix[a.length][b.length];
  }

  // RESTORED METHOD (THIS FIXES YOUR ERROR)

  MismatchSeverity evaluateMismatch(ContextType context, IntentType intent) {
    const highlyUnusual = {
      ContextType.paymentCounter: {
        IntentType.login,
        IntentType.download,
        IntentType.formSubmission,
      },
      ContextType.collegeNotice: {
        IntentType.payment,
        IntentType.download,
      },
      ContextType.restaurantMenu: {
        IntentType.login,
        IntentType.download,
        IntentType.payment,
        IntentType.formSubmission,
      },
      ContextType.publicPlace: {
        IntentType.login,
        IntentType.payment,
        IntentType.download,
      },
      ContextType.onlineImage: {
        IntentType.login,
        IntentType.payment,
        IntentType.download,
      },
    };

    const unusual = {
      ContextType.paymentCounter: {IntentType.formSubmission},
      ContextType.collegeNotice: {IntentType.formSubmission},
      ContextType.restaurantMenu: {IntentType.navigation},
    };

    if (highlyUnusual[context]?.contains(intent) == true) {
      return MismatchSeverity.highlyUnusual;
    }

    if (unusual[context]?.contains(intent) == true) {
      return MismatchSeverity.unusual;
    }

    return MismatchSeverity.normal;
  }
}