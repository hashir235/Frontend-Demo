import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/state_message_card.dart';

/// Renders one of our public legal pages inside the app.
///
/// The documents live on quickalapp.com so a policy fix never needs an app
/// release, but reviewers (and users) expect to read them without leaving the
/// app — so they open here rather than in an external browser.
class LegalDocumentScreen extends StatefulWidget {
  final String title;
  final String url;

  const LegalDocumentScreen({super.key, required this.title, required this.url});

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (WebResourceError error) {
            // Only a failure of the document itself matters; sub-resource
            // errors (fonts, icons) must not blank out a readable page.
            if (!mounted || !(error.isForMainFrame ?? false)) return;
            setState(() {
              _loading = false;
              _failed = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _failed
          ? Center(
              child: StateMessageCard(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load',
                message:
                    'We could not load this page. Check your internet connection '
                    'and try again.',
                iconColor: AppTheme.danger,
                action: FilledButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ),
            )
          : Stack(
              children: <Widget>[
                WebViewWidget(controller: _controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
