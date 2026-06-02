// lib/presentation/screens/risk_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';
import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';
import 'package:sqrprojectatlabendsem/files/presentation/providers/scan_notifier.dart';
import 'package:sqrprojectatlabendsem/files/presentation/widgets/common_widgets.dart';
import 'package:sqrprojectatlabendsem/files/presentation/screens/preview_screen.dart';

class RiskScreen extends ConsumerStatefulWidget {
  final ScanResult result;
  const RiskScreen({super.key, required this.result});

  @override
  ConsumerState<RiskScreen> createState() => _RiskScreenState();
}

class _RiskScreenState extends ConsumerState<RiskScreen> {
  // Deliberate friction — countdown before proceeding
  int _countdown = 5;
  bool _canProceed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final level = widget.result.riskAssessment?.level;
    // Only apply delay for medium/high risk
    if (level == RiskLevel.high || level == RiskLevel.medium) {
      _startCountdown();
    } else {
      _canProceed = true;
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _canProceed = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _proceed(String mode) async {
    await ref.read(scanNotifierProvider.notifier).recordDecision('proceed');

    if (!mounted) return;
    final url = widget.result.urlAnalysis?.rawUrl ?? widget.result.rawPayload;

    if (mode == 'preview') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PreviewScreen(url: url)),
      );
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _block() async {
    await ref.read(scanNotifierProvider.notifier).recordDecision('blocked');
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _dismiss() async {
    await ref.read(scanNotifierProvider.notifier).recordDecision('dismissed');
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final assessment = r.riskAssessment;
    final ua = r.urlAnalysis;
    final upi = r.upiDetails;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Assessment'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _dismiss,
            child: const Text('Dismiss'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Score Display ──────────────────────────────────────────────
            if (assessment != null) ...[
              Center(
                child: Column(
                  children: [
                    _RiskGauge(score: assessment.score, level: assessment.level),
                    const SizedBox(height: 16),
                    RiskBadge(
                      level: assessment.level,
                      score: assessment.score,
                      large: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Signals ──────────────────────────────────────────────────
              if (assessment.signals.isNotEmpty) ...[
                const SectionLabel('Why this score?'),
                SqrCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: assessment.signals
                        .map((s) => SignalItem(text: s))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const SqrCard(
                  child: SignalItem(
                    text: 'No structural risk signals detected.',
                    isWarning: false,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],

            // ── Redirect Chain ─────────────────────────────────────────────
            if (r.redirectChain.length > 1) ...[
              const SectionLabel('Redirect Chain'),
              SqrCard(
                child: Column(
                  children: r.redirectChain.asMap().entries.map((entry) {
                    final isLast = entry.key == r.redirectChain.length - 1;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isLast
                                  ? Icons.flag_outlined
                                  : Icons.arrow_downward,
                              size: 14,
                              color: isLast
                                  ? AppTheme.accent
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: isLast
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isLast) const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── UPI Confirmation ───────────────────────────────────────────
            if (upi != null) ...[
              const SectionLabel('Confirm Payment Details'),
              SqrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoRow(label: 'Payee VPA', value: upi.vpa),
                    if (upi.payeeName != null)
                      InfoRow(label: 'Payee Name', value: upi.payeeName!),
                    if (upi.amount != null)
                      InfoRow(
                        label: 'Amount',
                        value:
                            '${upi.currency} ${upi.amount!.toStringAsFixed(2)}',
                        valueColor: AppTheme.riskMedium,
                      ),
                    const SizedBox(height: 10),
                    const Text(
                      'Confirm with the merchant before proceeding. Once a UPI payment is sent it cannot be reversed automatically.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Destination ────────────────────────────────────────────────
            if (ua != null) ...[
              const SectionLabel('Final Destination'),
              SqrCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.redirectChain.isNotEmpty
                          ? r.redirectChain.last
                          : ua.rawUrl,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Friction countdown ─────────────────────────────────────────
            if (!_canProceed) ...[
              Center(
                child: Text(
                  'Review the details above — continuing in $_countdown…',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Decision Buttons ───────────────────────────────────────────
            if (ua != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canProceed ? () => _proceed('preview') : null,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(
                    _canProceed ? 'Safe Preview (recommended)' : 'Wait…',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canProceed
                        ? AppTheme.accent
                        : AppTheme.surfaceVariant,
                    foregroundColor: _canProceed
                        ? AppTheme.background
                        : AppTheme.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _canProceed ? () => _proceed('browser') : null,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in External Browser'),
                ),
              ),
            ],

            if (upi != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _canProceed
                      ? () async {
                          await ref
                              .read(scanNotifierProvider.notifier)
                              .recordDecision('proceed');
                          final uri = Uri.tryParse(upi.rawIntent);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Proceed to UPI App'),
                ),
              ),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _block,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Block & Report Domain'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.riskHigh.withOpacity(0.15),
                  foregroundColor: AppTheme.riskHigh,
                  side: BorderSide(color: AppTheme.riskHigh.withOpacity(0.4)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Risk Gauge (circular) ────────────────────────────────────────────────────
class _RiskGauge extends StatefulWidget {
  final int score;
  final RiskLevel level;

  const _RiskGauge({required this.score, required this.level});

  @override
  State<_RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<_RiskGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Color get _color {
    switch (widget.level) {
      case RiskLevel.low:
        return AppTheme.riskLow;
      case RiskLevel.medium:
        return AppTheme.riskMedium;
      case RiskLevel.high:
        return AppTheme.riskHigh;
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _animation = Tween<double>(
      begin: 0,
      end: widget.score.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) {
          final value = _animation.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 200),
                painter: _GaugePainter(
                  progress: value / 100,
                  color: _color,
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: _color,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Risk Score',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // background circle
    canvas.drawCircle(center, radius - 14, backgroundPaint);

    // progress arc
    final sweepAngle = 2 * 3.1415926535 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 14),
      -3.1415926535 / 2, // start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}