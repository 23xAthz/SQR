// lib/presentation/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';
import 'package:sqrprojectatlabendsem/files/data/local/database_helper.dart';
import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';
import 'package:sqrprojectatlabendsem/files/presentation/providers/scan_notifier.dart';
import 'package:sqrprojectatlabendsem/files/presentation/widgets/common_widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear history',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppTheme.surface,
                  title: const Text('Clear all history?'),
                  content: const Text(
                    'This will remove all scan records and flagged domains.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: AppTheme.riskHigh),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DatabaseHelper.instance.clearHistory();
                ref.invalidate(historyProvider);
              }
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
        error: (e, _) => Center(
          child: Text(
            'Error loading history: $e',
            style: const TextStyle(color: AppTheme.riskHigh),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, color: AppTheme.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No scan history yet',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _HistoryCard(row: rows[i]),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _HistoryCard({required this.row});

  Color _decisionColor(String? decision) {
    switch (decision) {
      case 'proceed':
        return AppTheme.riskLow;
      case 'blocked':
        return AppTheme.riskHigh;
      default:
        return AppTheme.textMuted;
    }
  }

  String _decisionLabel(String? decision) {
    switch (decision) {
      case 'proceed':
        return 'Proceeded';
      case 'blocked':
        return 'Blocked';
      case 'dismissed':
        return 'Dismissed';
      default:
        return 'Unknown';
    }
  }

  RiskLevel? _parseLevel(String? s) {
    switch (s) {
      case 'low':
        return RiskLevel.low;
      case 'medium':
        return RiskLevel.medium;
      case 'high':
        return RiskLevel.high;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final decision = row['user_decision'] as String?;
    final domain = row['domain'] as String?;
    final payload = row['raw_payload'] as String? ?? '';
    final scoreRaw = row['risk_score'];
    final score = scoreRaw != null ? (scoreRaw as int) : null;
    final level = _parseLevel(row['risk_level'] as String?);
    final scannedAt = row['scanned_at'] as String? ?? '';
    final intent = row['intent'] as String?;
    final payloadType = row['payload_type'] as String? ?? 'unknown';

    DateTime? dt;
    try {
      dt = DateTime.parse(scannedAt).toLocal();
    } catch (_) {}

    return SqrCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Expanded(
                child: Text(
                  domain ?? payload,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (level != null && score != null)
                RiskBadge(level: level, score: score),
            ],
          ),
          const SizedBox(height: 6),

          // Sub info
          Row(
            children: [
              _Tag(payloadType.toUpperCase()),
              if (intent != null) ...[
                const SizedBox(width: 6),
                _Tag(intent),
              ],
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _decisionColor(decision).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _decisionLabel(decision),
                  style: TextStyle(
                    color: _decisionColor(decision),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          if (dt != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_fmt(dt)}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}


