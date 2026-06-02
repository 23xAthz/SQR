// lib/data/services/upi_parser.dart

import 'package:sqrprojectatlabendsem/files/domain/entities/scan_result.dart';

class UpiParserService {
  /// Returns parsed UpiDetails if the payload is a UPI intent URI, else null.
  UpiDetails? parse(String payload) {

    final decodedPayload = Uri.decodeFull(payload);
    final lower = decodedPayload.toLowerCase().trim();

    // UPI deep links: upi://pay?... or intent://pay?... scheme wrappers
    if (!lower.startsWith('upi://') &&
        !lower.startsWith('intent://') &&
        !lower.contains('upi://pay')) {
      return null;
    }

    // Extract the upi://pay portion if wrapped in intent://
    String upiUri = decodedPayload;

    if (lower.startsWith('intent://')) {

      final match = RegExp(
        r'''upi://pay[^\s"'>]*''',
        caseSensitive: false,
      ).firstMatch(decodedPayload);

      if (match != null) {
        upiUri = match.group(0)!;
      } else {

        final intentUri = Uri.tryParse(decodedPayload);
        if (intentUri != null && intentUri.host == 'pay') {
          upiUri = 'upi://pay?${intentUri.query}';
        } else {
          return null;
        }
      }
    }

    final uri = Uri.tryParse(upiUri);
    if (uri == null) return null;

    final params = uri.queryParameters;
    final vpa = params['pa']?.trim();


    if (vpa == null || vpa.isEmpty || !vpa.contains('@')) return null;

    final payeeName = params['pn'];
    final amountStr = params['am'];
    final currency = params['cu'] ?? 'INR';

    double? amount;
    if (amountStr != null) {
      amount = double.tryParse(amountStr);
    }

    return UpiDetails(
      rawIntent: payload, // keep original (good design)
      vpa: vpa,
      payeeName: payeeName,
      amount: amount,
      currency: currency,
    );
  }

  bool isUpiPayload(String payload) {
    final lower = payload.toLowerCase();


    return lower.startsWith('upi://') ||
        lower.contains('upi://pay?') ||
        (lower.startsWith('intent://') && lower.contains('upi'));
  }
}