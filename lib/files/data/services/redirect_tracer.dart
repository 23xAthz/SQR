// lib/data/services/redirect_tracer.dart

import 'package:http/http.dart' as http;

const _maxRedirects = 5;
const _timeoutSeconds = 6;

class RedirectTracerService {
  /// Follows redirects manually (no auto-follow) and returns the chain.
  /// Does not render content or execute scripts.
  Future<List<String>> trace(String startUrl) async {
    final chain = <String>[startUrl];
    String current = startUrl;

    for (int i = 0; i < _maxRedirects; i++) {
      try {
        final uri = Uri.tryParse(current);
        if (uri == null) break;

        final response = await http
            .head(uri)
            .timeout(const Duration(seconds: _timeoutSeconds));

        final location = response.headers['location'];

        // No redirect header — we've reached the final destination
        if (location == null || location.isEmpty) break;

        // Handle relative redirects
        final nextUri = Uri.tryParse(location);
        if (nextUri == null) break;

        final resolved = nextUri.isAbsolute
            ? location
            : uri.resolve(location).toString();

        // Stop if we've somehow looped back
        if (chain.contains(resolved)) break;

        chain.add(resolved);
        current = resolved;

        // Stop if not a redirect status
        final status = response.statusCode;
        if (status < 300 || status >= 400) break;
      } catch (_) {
        // Network error, timeout, or malformed — stop gracefully
        break;
      }
    }

    return chain;
  }

  String get finalDestination => ''; // caller uses chain.last
}
