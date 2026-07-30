import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String? orderNumber;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    this.orderNumber,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  // webview_flutter has no web-platform implementation, so an embedded
  // WebView isn't usable there; on web we do a top-level redirect instead
  // (matching how the reference web app hands off via `window.location.href`,
  // which also sidesteps payment gateways refusing to render inside an iframe).
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _redirectOnWeb();
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _isLoading = true);
          _handleCallback(url);
        },
        onPageFinished: (url) {
          setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _redirectOnWeb() async {
    await launchUrl(Uri.parse(widget.paymentUrl), webOnlyWindowName: '_self');
  }

  void _handleCallback(String url) {
    if (_hasNavigated) return;

    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();

    // Check for payment callback URLs
    if (path.contains('paymentresult') || path.contains('payment-result') || path.contains('callback')) {
      _hasNavigated = true;
      // Extract query parameters and navigate to result screen
      final params = uri.queryParameters;
      final resultParams = <String, String>{
        if (params.containsKey('status')) 'status': params['status']!,
        if (params.containsKey('txnid')) 'txnid': params['txnid']!,
        if (params.containsKey('txnId')) 'txnId': params['txnId']!,
        if (params.containsKey('error')) 'error': params['error']!,
        if (widget.orderNumber != null) 'orderNumber': widget.orderNumber!,
      };

      final resultQueryString = resultParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      if (mounted) {
        context.go('/payment-result?$resultQueryString');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _showCancelDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _showCancelDialog,
          ),
          title: const Text('Payment', style: TextStyle(color: Colors.white, fontSize: 18)),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF523DA9), Color(0xFF4C42B8), Color(0xFF5365DF)]),
            ),
          ),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (_controller != null) WebViewWidget(controller: _controller!),
            if (_isLoading)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF523DA9)),
                    const SizedBox(height: 16),
                    Text(
                      kIsWeb ? 'Redirecting to secure payment...' : 'Processing payment...',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text('Are you sure you want to cancel this payment? Your order may not be completed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.orderNumber != null) {
                context.go('/payment-result?status=usercancelled&orderNumber=${widget.orderNumber}');
              } else {
                context.go('/cart');
              }
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
