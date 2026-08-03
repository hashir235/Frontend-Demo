import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/theme/app_theme.dart';

/// How the checkout finished, from the app's point of view only.
///
/// [paid] means Safepay sent the customer to our return URL — it does NOT mean
/// the subscription is on. Entitlement always comes from Safepay's signed
/// webhook, so the caller must re-read /api/subscription/status afterwards.
enum SafepayCheckoutResult { paid, cancelled, dismissed }

/// Hosted Safepay checkout in an in-app WebView.
///
/// Card details are entered on Safepay's page and never touch this app or our
/// server. We watch navigation for the return/cancel URLs our backend gave
/// Safepay, and close as soon as one is hit.
class SafepayCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String returnUrlPrefix;
  final String cancelUrlPrefix;

  const SafepayCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.returnUrlPrefix,
    required this.cancelUrlPrefix,
  });

  @override
  State<SafepayCheckoutScreen> createState() => _SafepayCheckoutScreenState();
}

class _SafepayCheckoutScreenState extends State<SafepayCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            _handleUrl(url);
            if (mounted && !_closed) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (String _) {
            if (mounted && !_closed) {
              setState(() => _loading = false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Close on our own return/cancel URLs instead of rendering them.
            if (_handleUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            // Sub-resource failures are noisy and usually harmless; only a
            // failure of the checkout page itself is worth surfacing.
            if (!mounted || _closed || !error.isForMainFrame!) {
              return;
            }
            setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    _allowThirdPartyCookies();
  }

  /// Safepay renders the card-number and CVV inputs as cross-origin iframes.
  /// The Android WebView blocks third-party cookies by default, so those
  /// iframes never finish initialising and the Pay button stays disabled —
  /// the checkout looks broken even though everything else is filled in.
  Future<void> _allowThirdPartyCookies() async {
    final WebViewController controller = _controller;
    if (controller.platform is! AndroidWebViewController) {
      return;
    }
    final cookieManager = WebViewCookieManager().platform;
    if (cookieManager is! AndroidWebViewCookieManager) {
      return;
    }
    try {
      await cookieManager.setAcceptThirdPartyCookies(
        controller.platform as AndroidWebViewController,
        true,
      );
    } catch (_) {
      // Best effort: if this fails the page still loads, so let the user try.
    }
  }

  /// Returns true when [url] was one of ours and the screen is closing.
  bool _handleUrl(String url) {
    if (_closed) {
      return true;
    }
    if (url.startsWith(widget.returnUrlPrefix)) {
      _close(SafepayCheckoutResult.paid);
      return true;
    }
    if (url.startsWith(widget.cancelUrlPrefix)) {
      _close(SafepayCheckoutResult.cancelled);
      return true;
    }
    return false;
  }

  void _close(SafepayCheckoutResult result) {
    if (_closed || !mounted) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<SafepayCheckoutResult>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, SafepayCheckoutResult? _) async {
        if (didPop || _closed) {
          return;
        }
        final bool leave = await _confirmLeave();
        if (leave) {
          _close(SafepayCheckoutResult.dismissed);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Cancel payment',
            onPressed: () async {
              if (await _confirmLeave()) {
                _close(SafepayCheckoutResult.dismissed);
              }
            },
          ),
        ),
        body: Stack(
          children: <Widget>[
            WebViewWidget(controller: _controller),
            if (_loading)
              const ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  // Leaving mid-payment can strand a real charge, so make it deliberate.
  Future<bool> _confirmLeave() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'Your payment is not finished yet. If you leave now, no subscription '
          'will be activated.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep paying'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }
}
