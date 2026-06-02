// lib/data/services/threat_intel_service.dart
//
// Advisory-only. Failure or unavailability never blocks analysis.
// API keys are set in ThreatIntelConfig (user-supplied).

import 'dart:convert';
import 'package:http/http.dart' as http;

class ThreatIntelResult {
  final String source;
  final bool flagged;
  final String? reason;
  final int? positives; // for VT: malicious vote count

  const ThreatIntelResult({
    required this.source,
    required this.flagged,
    this.reason,
    this.positives,
  });
}

class ThreatIntelService {
  final String? virusTotalApiKey;
  final String? googleSafeBrowsingApiKey;
  final String? abuseIpDbApiKey;

  static const _timeout = Duration(seconds: 8);

  ThreatIntelService({
    this.virusTotalApiKey,
    this.googleSafeBrowsingApiKey,
    this.abuseIpDbApiKey,
  });

  /// Runs all configured checks in parallel and returns results.
  /// Always resolves — errors per-source are swallowed and marked as
  /// [flagged: false] with a note.
  Future<List<ThreatIntelResult>> checkDomain(String domain) async {
    final futures = <Future<ThreatIntelResult>>[];

    if (virusTotalApiKey != null && virusTotalApiKey!.isNotEmpty) {
      futures.add(_checkVirusTotal(domain));
    }
    if (googleSafeBrowsingApiKey != null &&
        googleSafeBrowsingApiKey!.isNotEmpty) {
      futures.add(_checkGoogleSafeBrowsing(domain));
    }
    if (abuseIpDbApiKey != null && abuseIpDbApiKey!.isNotEmpty) {
      futures.add(_checkAbuseIpDb(domain));
    }

    if (futures.isEmpty) return [];

    final results = await Future.wait(futures, eagerError: false);
    return results;
  }

  bool anyFlagged(List<ThreatIntelResult> results) =>
      results.any((r) => r.flagged);

  // ─── VirusTotal ───────────────────────────────────────────────────────────
  // Uses the v3 domain-report endpoint (read-only reputation check, no upload)

  Future<ThreatIntelResult> _checkVirusTotal(String domain) async {
    try {
      final encoded = base64Url.encode(utf8.encode(domain)).replaceAll('=', '');
      final uri = Uri.parse(
        'https://www.virustotal.com/api/v3/domains/$encoded',
      );
      final response = await http.get(
        uri,
        headers: {'x-apikey': virusTotalApiKey!},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats =
            data['data']?['attributes']?['last_analysis_stats'] as Map?;
        final malicious = (stats?['malicious'] as int?) ?? 0;
        final suspicious = (stats?['suspicious'] as int?) ?? 0;
        final total = malicious + suspicious;

        return ThreatIntelResult(
          source: 'VirusTotal',
          flagged: total > 0,
          positives: total,
          reason: total > 0
              ? '$malicious malicious, $suspicious suspicious detections'
              : null,
        );
      }

      return const ThreatIntelResult(
        source: 'VirusTotal',
        flagged: false,
        reason: 'Could not retrieve report',
      );
    } catch (_) {
      return const ThreatIntelResult(
        source: 'VirusTotal',
        flagged: false,
        reason: 'Unavailable',
      );
    }
  }

  // ─── Google Safe Browsing ─────────────────────────────────────────────────
  // Lookup API v4 — sends URL, gets threat matches back

  Future<ThreatIntelResult> _checkGoogleSafeBrowsing(String domain) async {
    try {
      final uri = Uri.parse(
        'https://safebrowsing.googleapis.com/v4/threatMatches:find'
        '?key=$googleSafeBrowsingApiKey',
      );

      final body = jsonEncode({
        'client': {'clientId': 'sqr_app', 'clientVersion': '1.0.0'},
        'threatInfo': {
          'threatTypes': [
            'MALWARE',
            'SOCIAL_ENGINEERING',
            'UNWANTED_SOFTWARE',
            'POTENTIALLY_HARMFUL_APPLICATION',
          ],
          'platformTypes': ['ANY_PLATFORM'],
          'threatEntryTypes': ['URL'],
          'threatEntries': [
            {'url': 'https://$domain'},
            {'url': 'http://$domain'},
          ],
        },
      });

      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final matches = data['matches'] as List?;
        final flagged = matches != null && matches.isNotEmpty;

        String? reason;
        if (flagged) {
          final types = matches!
              .map((m) => m['threatType'] as String? ?? '')
              .toSet()
              .join(', ');
          reason = 'Threats: $types';
        }

        return ThreatIntelResult(
          source: 'Google Safe Browsing',
          flagged: flagged,
          reason: reason,
        );
      }

      return const ThreatIntelResult(
        source: 'Google Safe Browsing',
        flagged: false,
        reason: 'Could not retrieve report',
      );
    } catch (_) {
      return const ThreatIntelResult(
        source: 'Google Safe Browsing',
        flagged: false,
        reason: 'Unavailable',
      );
    }
  }

  // ─── AbuseIPDB ────────────────────────────────────────────────────────────
  // Used for IP-based URLs only; skip if domain is not an IP

  Future<ThreatIntelResult> _checkAbuseIpDb(String domain) async {
    // Only meaningful for IPs
    final isIp = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(domain);
    if (!isIp) {
      return const ThreatIntelResult(
        source: 'AbuseIPDB',
        flagged: false,
        reason: 'Not an IP address — skipped',
      );
    }

    try {
      final uri = Uri.parse(
        'https://api.abuseipdb.com/api/v2/check?ipAddress=$domain&maxAgeInDays=90',
      );
      final response = await http.get(
        uri,
        headers: {
          'Key': abuseIpDbApiKey!,
          'Accept': 'application/json',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final score = (data['data']?['abuseConfidenceScore'] as int?) ?? 0;
        final flagged = score >= 25;

        return ThreatIntelResult(
          source: 'AbuseIPDB',
          flagged: flagged,
          reason: flagged ? 'Abuse confidence score: $score/100' : null,
          positives: score,
        );
      }

      return const ThreatIntelResult(
        source: 'AbuseIPDB',
        flagged: false,
        reason: 'Could not retrieve report',
      );
    } catch (_) {
      return const ThreatIntelResult(
        source: 'AbuseIPDB',
        flagged: false,
        reason: 'Unavailable',
      );
    }
  }
}
