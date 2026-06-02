// lib/presentation/screens/analysis_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';
import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';
import 'package:sqrprojectatlabendsem/files/presentation/providers/scan_notifier.dart';
import 'package:sqrprojectatlabendsem/files/presentation/widgets/common_widgets.dart';
import 'package:sqrprojectatlabendsem/files/presentation/screens/risk_screen.dart';

class AnalysisScreen extends ConsumerStatefulWidget {
  final ScanResult result;
  const AnalysisScreen({super.key, required this.result});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  ContextType _selectedContext = ContextType.publicPlace;
  bool _traceRedirects = true;

  static const _contextLabels = {
    ContextType.paymentCounter: ('Payment Counter', Icons.point_of_sale),
    ContextType.collegeNotice: ('College Notice', Icons.school),
    ContextType.restaurantMenu: ('Restaurant Menu', Icons.restaurant_menu),
    ContextType.publicPlace: ('Public Place', Icons.location_on),
    ContextType.onlineImage: ('Online / Image', Icons.image),
  };

  Future<void> _runAnalysis() async {
    await ref.read(scanNotifierProvider.notifier).runAnalysis(
          context: _selectedContext,
          traceRedirects: _traceRedirects,
        );

    final current = ref.read(scanNotifierProvider).current;
    if (current != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RiskScreen(result: current)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanNotifierProvider);
    final r = widget.result;
    final ua = r.urlAnalysis;
    final upi = r.upiDetails;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text(
                    'Tracing redirects & scoring risk…',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Payload Type Badge ─────────────────────────────────
                  _PayloadTypeBadge(type: r.payloadType),
                  const SizedBox(height: 16),

                  // ── Raw Payload ────────────────────────────────────────
                  const SectionLabel('Raw Payload'),
                  SqrCard(
                    child: SelectableText(
                      r.rawPayload,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── URL Breakdown ──────────────────────────────────────
                  if (ua != null) ...[
                    const SectionLabel('URL Breakdown'),
                    SqrCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InfoRow(label: 'Protocol', value: ua.scheme.toUpperCase()),
                          InfoRow(
                            label: 'Domain',
                            value: ua.domain,
                            valueColor: AppTheme.accent,
                          ),
                          if (ua.path.isNotEmpty)
                            InfoRow(label: 'Path', value: ua.path),
                          if (ua.queryParams.isNotEmpty)
                            InfoRow(
                              label: 'Parameters',
                              value: ua.queryParams.entries
                                  .map((e) => '${e.key}=${e.value}')
                                  .join('\n'),
                            ),
                          const Divider(height: 20),
                          _FlagRow(
                            label: 'HTTPS',
                            isGood: ua.isHttps,
                            goodText: 'Encrypted',
                            badText: 'Unencrypted (HTTP)',
                          ),
                          _FlagRow(
                            label: 'IP-based URL',
                            isGood: !ua.isIpBased,
                            goodText: 'Domain name',
                            badText: 'Raw IP address detected',
                          ),
                          _FlagRow(
                            label: 'URL Shortener',
                            isGood: !ua.isShortener,
                            goodText: 'Not a shortener',
                            badText: 'Destination is hidden',
                          ),
                          _FlagRow(
                            label: 'Punycode',
                            isGood: !ua.hasPunycode,
                            goodText: 'Clean domain',
                            badText: 'Potential homograph attack',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Intent
                    Row(
                      children: [
                        const Text(
                          'Detected intent: ',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        IntentChip(intent: ua.intent),
                      ],
                    ),
                    if (ua.suspiciousKeywords.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: ua.suspiciousKeywords
                            .map(
                              (kw) => Chip(
                                label: Text(kw),
                                backgroundColor:
                                    AppTheme.riskHigh.withOpacity(0.12),
                                labelStyle: const TextStyle(
                                  color: AppTheme.riskHigh,
                                  fontSize: 11,
                                ),
                                side: BorderSide(
                                  color: AppTheme.riskHigh.withOpacity(0.3),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],

                  // ── UPI Details ────────────────────────────────────────
                  if (upi != null) ...[
                    const SectionLabel('UPI Payment Details'),
                    SqrCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InfoRow(
                            label: 'VPA (Address)',
                            value: upi.vpa,
                            valueColor: AppTheme.accent,
                          ),
                          if (upi.payeeName != null)
                            InfoRow(label: 'Payee Name', value: upi.payeeName!),
                          if (upi.amount != null)
                            InfoRow(
                              label: 'Amount',
                              value: '${upi.currency} ${upi.amount!.toStringAsFixed(2)}',
                              valueColor: AppTheme.riskMedium,
                            )
                          else
                            const InfoRow(
                              label: 'Amount',
                              value: 'Not specified in QR',
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.riskMedium.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.riskMedium.withOpacity(0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppTheme.riskMedium,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verify the payee name and VPA with the merchant before proceeding.',
                              style: TextStyle(
                                color: AppTheme.riskMedium,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Context Selection ──────────────────────────────────
                  const SectionLabel('Where did you find this QR code?'),
                  SqrCard(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: ContextType.values.map((ct) {
                        final (label, icon) = _contextLabels[ct]!;
                        final selected = ct == _selectedContext;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            icon,
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            size: 20,
                          ),
                          title: Text(
                            label,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.accent
                                  : AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppTheme.accent,
                                  size: 18,
                                )
                              : null,
                          onTap: () =>
                              setState(() => _selectedContext = ct),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          tileColor: selected
                              ? AppTheme.accent.withOpacity(0.06)
                              : null,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Redirect toggle
                  if (r.payloadType == QrPayloadType.url)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Trace redirect chain',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Requires brief network access',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      value: _traceRedirects,
                      activeColor: AppTheme.accent,
                      onChanged: (v) => setState(() => _traceRedirects = v),
                    ),

                  const SizedBox(height: 24),

                  // ── CTA ───────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runAnalysis,
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Run Risk Assessment'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel & Return to Scanner'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ─── Payload Type Badge ───────────────────────────────────────────────────────

class _PayloadTypeBadge extends StatelessWidget {
  final QrPayloadType type;
  const _PayloadTypeBadge({required this.type});

  String get _label {
    switch (type) {
      case QrPayloadType.url:
        return 'URL';
      case QrPayloadType.upi:
        return 'UPI PAYMENT';
      case QrPayloadType.text:
        return 'PLAIN TEXT';
      case QrPayloadType.unknown:
        return 'UNKNOWN';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.qr_code_2, color: AppTheme.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          'Payload type: $_label',
          style: const TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ─── Flag Row (good/bad indicator) ───────────────────────────────────────────

class _FlagRow extends StatelessWidget {
  final String label;
  final bool isGood;
  final String goodText;
  final String badText;

  const _FlagRow({
    required this.label,
    required this.isGood,
    required this.goodText,
    required this.badText,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGood ? AppTheme.riskLow : AppTheme.riskHigh;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            isGood ? goodText : badText,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
