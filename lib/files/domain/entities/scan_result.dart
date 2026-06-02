// lib/domain/entities/scan_result.dart

enum QrPayloadType { url, upi, text, unknown }

enum IntentType {
  login,
  payment,
  download,
  formSubmission,
  navigation,
  unknown,
}

enum RiskLevel { low, medium, high }

enum ContextType {
  paymentCounter,
  collegeNotice,
  restaurantMenu,
  publicPlace,
  onlineImage,
}

enum MismatchSeverity { normal, unusual, highlyUnusual }

class UrlAnalysis {
  final String rawUrl;
  final String scheme;
  final String domain;
  final String path;
  final Map<String, String> queryParams;

  final bool isHttps;
  final bool isIpBased;
  final bool isShortener;
  final bool hasPunycode;

  // 🔥 NEW ADVANCED SIGNALS
  final bool isLookalikeDomain;
  final bool hasSuspiciousTld;
  final bool hasExcessiveSubdomains;
  final double domainEntropy;

  final List<String> suspiciousKeywords;
  final IntentType intent;

  const UrlAnalysis({
    required this.rawUrl,
    required this.scheme,
    required this.domain,
    required this.path,
    required this.queryParams,
    required this.isHttps,
    required this.isIpBased,
    required this.isShortener,
    required this.hasPunycode,
    required this.suspiciousKeywords,
    required this.intent,

    // defaults so old code doesn't break
    this.isLookalikeDomain = false,
    this.hasSuspiciousTld = false,
    this.hasExcessiveSubdomains = false,
    this.domainEntropy = 0,
  });
}

class UpiDetails {
  final String rawIntent;
  final String vpa;
  final String? payeeName;
  final double? amount;
  final String currency;

  const UpiDetails({
    required this.rawIntent,
    required this.vpa,
    this.payeeName,
    this.amount,
    this.currency = 'INR',
  });
}

class RiskAssessment {
  final int score;
  final RiskLevel level;
  final List<String> signals;
  final MismatchSeverity contextMismatch;

  const RiskAssessment({
    required this.score,
    required this.level,
    required this.signals,
    required this.contextMismatch,
  });

  static RiskLevel levelFromScore(int score) {
    if (score <= 30) return RiskLevel.low;
    if (score <= 60) return RiskLevel.medium;
    return RiskLevel.high;
  }
}

class ScanResult {
  final String id;
  final String rawPayload;
  final String payloadHash;
  final QrPayloadType payloadType;
  final UrlAnalysis? urlAnalysis;
  final UpiDetails? upiDetails;
  final RiskAssessment? riskAssessment;
  final List<String> redirectChain;
  final ContextType? context;
  final DateTime scannedAt;
  final String? userDecision;

  const ScanResult({
    required this.id,
    required this.rawPayload,
    required this.payloadHash,
    required this.payloadType,
    this.urlAnalysis,
    this.upiDetails,
    this.riskAssessment,
    this.redirectChain = const [],
    this.context,
    required this.scannedAt,
    this.userDecision,
  });

  ScanResult copyWith({
    RiskAssessment? riskAssessment,
    List<String>? redirectChain,
    ContextType? context,
    String? userDecision,
  }) {
    return ScanResult(
      id: id,
      rawPayload: rawPayload,
      payloadHash: payloadHash,
      payloadType: payloadType,
      urlAnalysis: urlAnalysis,
      upiDetails: upiDetails,
      riskAssessment: riskAssessment ?? this.riskAssessment,
      redirectChain: redirectChain ?? this.redirectChain,
      context: context ?? this.context,
      scannedAt: scannedAt,
      userDecision: userDecision ?? this.userDecision,
    );
  }
}