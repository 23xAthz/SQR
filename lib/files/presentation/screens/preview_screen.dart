// lib/presentation/screens/preview_screen.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';

class PreviewScreen extends StatefulWidget {
  final String url;
  const PreviewScreen({super.key, required this.url});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() {
            _loading = true;
            _currentUrl = url;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            // Block downloads and popups — only allow same-domain navigation
            if (_isDownloadAttempt(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _isDownloadAttempt(String url) {
    final lower = url.toLowerCase();
    const extensions = [
      '.apk', '.exe', '.zip', '.rar', '.dmg', '.msi',
      '.pdf', '.docx', '.xlsx', '.csv',
    ];
    return extensions.any((ext) => lower.endsWith(ext));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Safe Preview', style: TextStyle(fontSize: 16)),
            Text(
              _currentUrl,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in external browser',
            onPressed: () async {
              final uri = Uri.tryParse(_currentUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Warning banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: AppTheme.riskMedium.withOpacity(0.12),
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: AppTheme.riskMedium,
                  size: 14,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'JavaScript disabled  ·  Downloads blocked  ·  Preview mode',
                    style: TextStyle(
                      color: AppTheme.riskMedium,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            const LinearProgressIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.border,
            ),

          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
