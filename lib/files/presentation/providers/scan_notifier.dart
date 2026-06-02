// lib/presentation/providers/scan_notifier.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';
import 'package:sqrprojectatlabendsem/files/data/services/url_analyzer.dart';
import 'package:sqrprojectatlabendsem/files/data/services/upi_parser.dart';
import 'package:sqrprojectatlabendsem/files/data/services/risk_scorer.dart';
import 'package:sqrprojectatlabendsem/files/data/services/redirect_tracer.dart';
import 'package:sqrprojectatlabendsem/files/data/services/threat_intel_service.dart';
import 'package:sqrprojectatlabendsem/files/data/local/database_helper.dart';
import 'package:sqrprojectatlabendsem/files/data/local/settings_store.dart';

// ─── Service Providers ───────────────────────────────────────────────────────

final urlAnalyzerProvider = Provider((_) => UrlAnalyzerService());
final upiParserProvider = Provider((_) => UpiParserService());
final riskScorerProvider = Provider((_) => RiskScorerService());
final redirectTracerProvider = Provider((_) => RedirectTracerService());
final dbProvider = Provider((_) => DatabaseHelper.instance);
final settingsProvider = Provider((_) => SettingsStore.instance);

final threatIntelProvider = Provider((ref) {
  final s = ref.read(settingsProvider);
  return ThreatIntelService(
    virusTotalApiKey: s.virusTotalKey.isEmpty ? null : s.virusTotalKey,
    googleSafeBrowsingApiKey:
        s.googleSafeBrowsingKey.isEmpty ? null : s.googleSafeBrowsingKey,
    abuseIpDbApiKey: s.abuseIpDbKey.isEmpty ? null : s.abuseIpDbKey,
  );
});

// ─── Scan State ──────────────────────────────────────────────────────────────

class ScanState {
  final ScanResult? current;
  final bool isLoading;
  final String? error;
  final bool scannerPaused;

  const ScanState({
    this.current,
    this.isLoading = false,
    this.error,
    this.scannerPaused = false,
  });

  ScanState copyWith({
    ScanResult? current,
    bool? isLoading,
    String? error,
    bool? scannerPaused,
  }) {
    return ScanState(
      current: current ?? this.current,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scannerPaused: scannerPaused ?? this.scannerPaused,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  final UrlAnalyzerService _urlAnalyzer;
  final UpiParserService _upiParser;
  final RiskScorerService _riskScorer;
  final RedirectTracerService _redirectTracer;
  final DatabaseHelper _db;

  ScanNotifier(
    this._urlAnalyzer,
    this._upiParser,
    this._riskScorer,
    this._redirectTracer,
    this._db,
  ) : super(const ScanState());

  // ─── Step 1: Decode and classify QR payload ─────────────────────────────

  Future<ScanResult?> processQrPayload(String rawPayload) async {
    if (state.scannerPaused) return null;
    state = state.copyWith(scannerPaused: true, isLoading: true, error: null);

    try {
      final hash = _computeHash(rawPayload);
      final payloadType = _classifyPayload(rawPayload);

      UrlAnalysis? urlAnalysis;
      UpiDetails? upiDetails;

      if (payloadType == QrPayloadType.url) {
        urlAnalysis = _urlAnalyzer.analyze(rawPayload);
      } else if (payloadType == QrPayloadType.upi) {
        upiDetails = _upiParser.parse(rawPayload);
      }

      final result = ScanResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        rawPayload: rawPayload,
        payloadHash: hash,
        payloadType: payloadType,
        urlAnalysis: urlAnalysis,
        upiDetails: upiDetails,
        scannedAt: DateTime.now(),
      );

      state = state.copyWith(current: result, isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to process QR code: $e',
        scannerPaused: false,
      );
      return null;
    }
  }

  // ─── Step 2: Run full analysis (redirect trace + risk score) ────────────

  Future<void> runAnalysis({
    required ContextType context,
    bool traceRedirects = true,
  }) async {
    final current = state.current;
    if (current == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      List<String> redirectChain = [];

      // Trace redirects for URLs only
      if (traceRedirects && current.payloadType == QrPayloadType.url) {
        redirectChain = await _redirectTracer.trace(current.rawPayload);
      }

      // Check DB for known flagged domain
      bool domainFlagged = false;
      if (current.urlAnalysis != null) {
        domainFlagged =
            await _db.isDomainFlagged(current.urlAnalysis!.domain);
      }

      // Context mismatch evaluation
      final mismatch = current.urlAnalysis != null
          ? _urlAnalyzer.evaluateMismatch(
              context,
              current.urlAnalysis!.intent,
            )
          : MismatchSeverity.normal;

      // Score
      RiskAssessment? assessment;
      if (current.urlAnalysis != null) {
        assessment = _riskScorer.score(
          urlAnalysis: current.urlAnalysis!,
          contextMismatch: mismatch,
          redirectDepth: redirectChain.length - 1,
          previouslyFlaggedDomain: domainFlagged,
        );
      }

      final updated = current.copyWith(
        context: context,
        redirectChain: redirectChain,
        riskAssessment: assessment,
      );

      // Persist scan (without decision yet)
      await _db.insertScan(updated);

      state = state.copyWith(current: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Analysis failed: $e',
      );
    }
  }

  // ─── Step 3: Record user decision ────────────────────────────────────────

  Future<void> recordDecision(String decision) async {
    final current = state.current;
    if (current == null) return;

    final updated = current.copyWith(userDecision: decision);
    await _db.updateDecision(current.id, decision);

    // If blocked, flag the domain for future reference
    if (decision == 'blocked' && current.urlAnalysis != null) {
      await _db.flagDomain(
        current.urlAnalysis!.domain,
        'User manually blocked',
      );
    }

    state = state.copyWith(current: updated);
  }

  // ─── Scanner control ─────────────────────────────────────────────────────

  void resumeScanner() {
    state = ScanState(); // full reset
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _computeHash(String payload) {
    final bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }

  QrPayloadType _classifyPayload(String payload) {
    final lower = payload.toLowerCase().trim();

    if (_upiParser.isUpiPayload(payload)) return QrPayloadType.upi;

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return QrPayloadType.url;
    }

    // Could also be a bare domain — try parsing
    final uri = Uri.tryParse(payload);
    if (uri != null && uri.hasScheme) return QrPayloadType.url;

    return QrPayloadType.text;
  }
}

// ─── Main Provider ───────────────────────────────────────────────────────────

final scanNotifierProvider =
    StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(
    ref.read(urlAnalyzerProvider),
    ref.read(upiParserProvider),
    ref.read(riskScorerProvider),
    ref.read(redirectTracerProvider),
    ref.read(dbProvider),
  );
});

// ─── History Provider ────────────────────────────────────────────────────────

final historyProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return DatabaseHelper.instance.getAllScans();
});
