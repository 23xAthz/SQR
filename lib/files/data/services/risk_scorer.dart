// lib/data/services/risk_scorer.dart

import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';

class RiskScorerService {
  RiskAssessment score({
    required UrlAnalysis urlAnalysis,
    required MismatchSeverity contextMismatch,
    int redirectDepth = 0,
    bool threatIntelFlagged = false,
    bool previouslyFlaggedDomain = false,
  }) {
    int score = 0;
    final signals = <String>[];
    bool isCritical = false;

    // ─────────────────────────────────────────────
    // STRUCTURAL SIGNALS
    // ─────────────────────────────────────────────

    if (!urlAnalysis.isHttps) {
      score += 20;
      signals.add('Unencrypted connection (HTTP instead of HTTPS)');
    }

    if (urlAnalysis.isIpBased) {
      score += 30;
      signals.add('URL uses a raw IP address instead of a domain name');
    }

    if (urlAnalysis.isShortener) {
      score += 25;
      signals.add('URL is a known shortener — final destination is hidden');
    }

    if (urlAnalysis.hasPunycode) {
      score += 25;
      signals.add('Punycode or homograph characters detected in domain');
    }

    // ─────────────────────────────────────────────
    // DOMAIN INTELLIGENCE
    // ─────────────────────────────────────────────

    if (urlAnalysis.isLookalikeDomain) {
      score += 35;
      signals.add('Domain closely resembles a trusted brand (possible phishing)');
    }

    if (urlAnalysis.hasSuspiciousTld) {
      score += 20;
      signals.add('Domain uses a suspicious or uncommon top-level domain');
    }

    if (urlAnalysis.hasExcessiveSubdomains) {
      score += 15;
      signals.add('Excessive subdomains detected — possible obfuscation');
    }

    // ─────────────────────────────────────────────
    // ENTROPY ANALYSIS
    // ─────────────────────────────────────────────

    if (urlAnalysis.domainEntropy > 4.0) {
      score += 25;
      signals.add('Domain appears randomly generated (high entropy)');
    } else if (urlAnalysis.domainEntropy > 3.5) {
      score += 15;
      signals.add('Domain shows unusual randomness');
    }

    // ─────────────────────────────────────────────
    // FILE / EXECUTION DETECTION
    // ─────────────────────────────────────────────

    try {
      final uri = Uri.parse(urlAnalysis.rawUrl);
      final path = uri.path.toLowerCase();

      if (path.endsWith('.apk') || path.endsWith('.exe')) {
        score += 40;
        isCritical = true;
        signals.add(
          'Executable file detected — may install malicious software',
        );
      } else if (path.endsWith('.zip') ||
          path.endsWith('.rar') ||
          path.endsWith('.pdf') ||
          path.endsWith('.doc') ||
          path.endsWith('.docx')) {
        score += 35;
        signals.add(
          'Direct file download detected — may trigger automatic download',
        );
      }

      if (uri.query.contains('download') ||
          uri.query.contains('file') ||
          uri.query.contains('attachment')) {
        score += 10;
        signals.add('URL contains download-related parameters');
      }
    } catch (_) {}

    // ─────────────────────────────────────────────
    // KEYWORD ANALYSIS
    // ─────────────────────────────────────────────

    final kwScore =
    (urlAnalysis.suspiciousKeywords.length * 10).clamp(0, 30);

    if (kwScore > 0) {
      score += kwScore;
      signals.add(
        'Suspicious keywords found: ${urlAnalysis.suspiciousKeywords.join(", ")}',
      );
    }

    // ─────────────────────────────────────────────
    // CONTEXT MISMATCH
    // ─────────────────────────────────────────────

    switch (contextMismatch) {
      case MismatchSeverity.highlyUnusual:
        score += 35;
        signals.add(
          'QR intent is highly unusual for its reported physical context',
        );
        break;
      case MismatchSeverity.unusual:
        score += 20;
        signals.add(
          'QR intent is somewhat unusual for its reported context',
        );
        break;
      case MismatchSeverity.normal:
        break;
    }

    // ─────────────────────────────────────────────
    // REDIRECT ANALYSIS
    // ─────────────────────────────────────────────

    if (redirectDepth == 1) {
      score += 10;
      signals.add('URL redirects once before reaching destination');
    } else if (redirectDepth == 2) {
      score += 20;
      signals.add('URL passes through 2 redirects');
    } else if (redirectDepth > 2) {
      score += 30;
      signals.add('Deep redirect chain detected ($redirectDepth hops)');
    }

    // ─────────────────────────────────────────────
    // EXTERNAL INTELLIGENCE
    // ─────────────────────────────────────────────

    if (threatIntelFlagged) {
      score += 40;
      signals.add('Domain flagged by external threat intelligence source');
    }

    if (previouslyFlaggedDomain) {
      score += 30;
      signals.add('This domain was previously flagged in a past session');
    }

    // ─────────────────────────────────────────────
    // MULTI-SIGNAL AGGREGATION
    // ─────────────────────────────────────────────

    if (signals.length >= 4) {
      score += 10;
    }

    if (signals.length >= 6) {
      score += 10;
    }

    if (signals.length >= 8) {
      score += 10;
    }

    // ─────────────────────────────────────────────
    // CRITICAL OVERRIDE
    // ─────────────────────────────────────────────

    if (isCritical && score < 60) {
      score = 60;
    }

    // ─────────────────────────────────────────────

    score = score.clamp(0, 100);

    final level = RiskAssessment.levelFromScore(score);

    return RiskAssessment(
      score: score,
      level: level,
      signals: signals,
      contextMismatch: contextMismatch,
    );
  }
}