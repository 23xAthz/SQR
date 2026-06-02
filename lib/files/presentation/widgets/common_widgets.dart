// lib/presentation/widgets/common_widgets.dart

import 'package:flutter/material.dart';
import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';
import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';
import 'package:sqrprojectatlabendsem/files/core/utils/signal_explanations.dart';

// ─── Risk Badge ───────────────────────────────────────────────────────────────

class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final int score;
  final bool large;

  const RiskBadge({
    super.key,
    required this.level,
    required this.score,
    this.large = false,
  });

  Color get _color {
    switch (level) {
      case RiskLevel.low:
        return AppTheme.riskLow;
      case RiskLevel.medium:
        return AppTheme.riskMedium;
      case RiskLevel.high:
        return AppTheme.riskHigh;
    }
  }

  String get _label {
    switch (level) {
      case RiskLevel.low:
        return 'LOW RISK';
      case RiskLevel.medium:
        return 'MEDIUM RISK';
      case RiskLevel.high:
        return 'HIGH RISK';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    if (large) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(
              _label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '$score/100',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Info Row ─────────────────────────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Signal Item ──────────────────────────────────────────────────────────────

class SignalItem extends StatelessWidget {
  final String text;
  final bool isWarning;

  const SignalItem({super.key, required this.text, this.isWarning = true});

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? AppTheme.riskHigh : AppTheme.textSecondary;
    final info = signalInfoMap[text];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: Icon(
              isWarning ? Icons.warning_amber_rounded : Icons.info_outline,
              size: 16,
              color: color,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (info != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Why: ${info.why}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Example: ${info.example}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Container ───────────────────────────────────────────────────────────

class SqrCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const SqrCard({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

// ─── Intent Chip ─────────────────────────────────────────────────────────────

class IntentChip extends StatelessWidget {
  final IntentType intent;
  const IntentChip({super.key, required this.intent});

  String get _label {
    switch (intent) {
      case IntentType.login:
        return 'Login / Auth';
      case IntentType.payment:
        return 'Payment';
      case IntentType.download:
        return 'Download';
      case IntentType.formSubmission:
        return 'Form Submission';
      case IntentType.navigation:
        return 'Navigation';
      case IntentType.unknown:
        return 'Unknown';
    }
  }

  Color get _color {
    switch (intent) {
      case IntentType.login:
        return AppTheme.riskMedium;
      case IntentType.payment:
        return const Color(0xFF818CF8);
      case IntentType.download:
        return AppTheme.riskHigh;
      case IntentType.formSubmission:
        return AppTheme.riskMedium;
      case IntentType.navigation:
        return AppTheme.riskLow;
      case IntentType.unknown:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}