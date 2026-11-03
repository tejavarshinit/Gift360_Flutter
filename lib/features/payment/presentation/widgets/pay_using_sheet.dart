import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/features/payment/data/models/payment_method_fee.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';
import 'package:gift360/features/payment/presentation/widgets/upi_intent_sheet.dart';

/// Full-screen "Pay using" chooser, ported from React `PayUsingSheet.tsx`:
///   UPI apps (per-app status/intent launches) + QR  -> Juspay UPI intent
///   NetBanking / Debit / Credit                     -> Easebuzz hosted
/// Every row shows the DB platform fee for that method.
class _UpiApp {
  final String key;
  final String label;
  final String scheme;
  const _UpiApp(this.key, this.label, this.scheme);
}

const List<_UpiApp> _upiApps = [
  _UpiApp('Gpay', 'Google Pay', 'tez://upi/pay?'),
  _UpiApp('PhonePe', 'PhonePe', 'phonepe://pay?'),
  _UpiApp('Paytm', 'Paytm', 'paytmmp://pay?'),
  _UpiApp('Cred', 'CRED', 'credpay://upi/pay?'),
  _UpiApp('BHIM', 'BHIM', 'bhim://pay?'),
];

const Map<String, (Color, Color)> _appAccent = {
  'Gpay': (Color(0xFFE8F0FE), Color(0xFF1A73E8)),
  'PhonePe': (Color(0xFFEFE7FF), Color(0xFF5F259F)),
  'Paytm': (Color(0xFFE6F6FF), Color(0xFF00A5EC)),
  'Cred': (Color(0xFFF1F1F4), Color(0xFF111827)),
  'BHIM': (Color(0xFFFFF1E6), Color(0xFFF58220)),
};

bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

String _money(double v) => '\u20b9${v.toStringAsFixed(2)}';

/// Shows the chooser. Resolves when it is dismissed.
Future<void> showPayUsingSheet({
  required BuildContext context,
  required String orderNumber,
  required double cashAmount,
  required List<PaymentMethodFee> methods,
  String? amountLabel,
  void Function(String orderNumber)? onLeavePending,
  void Function(String orderNumber)? onPaid,
  required void Function(String code) onCardMethod,
  VoidCallback? onFallbackToOtherMethods,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PayUsingSheet(
      orderNumber: orderNumber,
      cashAmount: cashAmount,
      methods: methods,
      amountLabel: amountLabel,
      onLeavePending: onLeavePending,
      onPaid: onPaid,
      onCardMethod: onCardMethod,
      onFallbackToOtherMethods: onFallbackToOtherMethods,
    ),
  );
}

class PayUsingSheet extends ConsumerStatefulWidget {
  final String orderNumber;

  /// Cash payable before the method fee (used for every fee row).
  final double cashAmount;
  final List<PaymentMethodFee> methods;
  final String? amountLabel;
  final void Function(String orderNumber)? onLeavePending;
  final void Function(String orderNumber)? onPaid;

  /// NetBanking / Debit / Credit -> Easebuzz (UPI is never sent there).
  final void Function(String code) onCardMethod;
  final VoidCallback? onFallbackToOtherMethods;

  const PayUsingSheet({
    super.key,
    required this.orderNumber,
    required this.cashAmount,
    required this.methods,
    this.amountLabel,
    this.onLeavePending,
    this.onPaid,
    required this.onCardMethod,
    this.onFallbackToOtherMethods,
  });

  @override
  ConsumerState<PayUsingSheet> createState() => _PayUsingSheetState();
}

class _PayUsingSheetState extends ConsumerState<PayUsingSheet> {
  bool _starting = false;
  String? _error;

  PaymentMethodFee? get _upiMethod {
    for (final m in widget.methods) {
      if (isUpiPaymentMethod(m.code)) return m;
    }
    return null;
  }

  double? get _upiFee {
    final m = _upiMethod;
    return m == null ? null : computeMethodFee(m, widget.cashAmount);
  }

  String? _total(double? fee) => fee == null ? null : _money(widget.cashAmount + fee);

  String? _resolveUrl(Map<String, dynamic> intent, String? appKey) {
    final deeplink = intent['deeplink']?.toString() ?? '';
    if (deeplink.isEmpty) return null;
    if (appKey == null || appKey.isEmpty) {
      // Android / desktop: the backend deeplink opens the system UPI chooser.
      // iOS never launches the generic upi:// scheme.
      return _isIos ? null : deeplink;
    }
    final hostUrls = (intent['hostUrlsForIOS'] as Map?)?.cast<String, dynamic>();
    final fromBackend = hostUrls?[appKey]?.toString();
    String? prefix;
    if (fromBackend != null &&
        fromBackend.trim().isNotEmpty &&
        !fromBackend.trim().toLowerCase().startsWith('upi://')) {
      prefix = fromBackend.trim();
    } else {
      for (final app in _upiApps) {
        if (app.key == appKey) prefix = app.scheme;
      }
    }
    if (prefix == null || prefix.toLowerCase().startsWith('upi://')) return null;
    final queryAt = deeplink.indexOf('?');
    if (queryAt < 0) return null;
    return '$prefix${deeplink.substring(queryAt + 1)}';
  }

  Future<Map<String, dynamic>?> _createIntent() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final response = await ref.read(orderApiProvider).createUpiIntent(widget.orderNumber);
      final deeplink = response['deeplink']?.toString() ?? '';
      if (deeplink.isEmpty) {
        throw response['responseMessage']?.toString() ?? 'Unable to start the UPI payment.';
      }
      return response;
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
      return null;
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _handleApp(_UpiApp app) async {
    final intent = await _createIntent();
    if (intent == null || !mounted) return;
    final url = _resolveUrl(intent, app.key);
    if (url == null) {
      setState(() => _error =
          "We couldn't build a ${app.label} link. Scan the QR code instead.");
      return;
    }
    final opened = await _launch(url);
    if (!opened && mounted) {
      setState(() => _error =
          "Couldn't open ${app.label}. Try another app or scan the QR code.");
      return;
    }
    _openProcessing(intent);
  }

  Future<void> _handleOtherApps() async {
    final intent = await _createIntent();
    if (intent == null || !mounted) return;
    final url = _resolveUrl(intent, null);
    if (url == null) {
      setState(() => _error = 'Scan the QR code below to pay.');
      return;
    }
    final opened = await _launch(url);
    if (!opened && mounted) {
      setState(() => _error = 'Could not open a UPI app. Scan the QR code instead.');
      return;
    }
    _openProcessing(intent);
  }

  Future<void> _handleQr() async {
    final intent = await _createIntent();
    if (intent == null || !mounted) return;
    _openProcessing(intent, qrValue: intent['deeplink']?.toString());
  }

  Future<bool> _launch(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void _openProcessing(Map<String, dynamic> intent, {String? qrValue}) {
    final parentContext = context;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      builder: (dialogContext) => UpiIntentSheet(
        orderNumber: widget.orderNumber,
        amountLabel: widget.amountLabel ?? _money(widget.cashAmount),
        initialIntent: intent,
        qrValue: qrValue,
        onClose: () {
          Navigator.of(dialogContext).pop();
          if (Navigator.of(parentContext).canPop()) Navigator.of(parentContext).pop();
        },
        onPaid: (orderNumber) {
          Navigator.of(dialogContext).pop();
          if (Navigator.of(parentContext).canPop()) Navigator.of(parentContext).pop();
          widget.onPaid?.call(orderNumber);
        },
        onViewOrders: () {
          Navigator.of(dialogContext).pop();
          if (Navigator.of(parentContext).canPop()) Navigator.of(parentContext).pop();
          widget.onPaid?.call(widget.orderNumber);
        },
        onLeavePending: () {
          Navigator.of(dialogContext).pop();
          if (Navigator.of(parentContext).canPop()) Navigator.of(parentContext).pop();
          widget.onLeavePending?.call(widget.orderNumber);
        },
        onFallbackToOtherMethods: () {
          Navigator.of(dialogContext).pop();
          if (Navigator.of(parentContext).canPop()) Navigator.of(parentContext).pop();
          widget.onFallbackToOtherMethods?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upiFee = _upiFee;
    final cardMethods = widget.methods.where((m) => !isUpiPaymentMethod(m.code)).toList();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            border: Border.all(color: const Color(0xFFFECACA)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFB91C1C)),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Text(
                            'UPI APPS',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const Spacer(),
                          if (upiFee != null)
                            Text(
                              'UPI fee ${_money(upiFee)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7C3AED),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = (constraints.maxWidth - 8) / 2;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _upiApps.map((app) {
                              final accent = _appAccent[app.key];
                              return SizedBox(
                                width: width,
                                child: _appButton(app, accent, upiFee),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      if (!_isIos) ...[
                        const SizedBox(height: 8),
                        _wideRow(
                          icon: Icons.smartphone,
                          label: 'Other UPI apps',
                          trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF5B2B99)),
                          onTap: _starting ? null : _handleOtherApps,
                          dashed: true,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _wideRow(
                        icon: Icons.qr_code_2,
                        label: 'Pay using QR',
                        trailing: Text(
                          _total(upiFee) ?? 'Scan',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        onTap: _starting ? null : _handleQr,
                        filled: true,
                      ),
                      if (cardMethods.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'CARDS & NETBANKING',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...cardMethods.map((method) {
                          final fee = computeMethodFee(method, widget.cashAmount);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _cardMethodRow(method, fee),
                          );
                        }),
                      ],
                      if (widget.onFallbackToOtherMethods != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: widget.onFallbackToOtherMethods == null
                              ? null
                              : () {
                                  Navigator.of(context).maybePop();
                                  widget.onFallbackToOtherMethods!();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5B2B99),
                            backgroundColor: const Color(0xFFF7F2FF),
                            side: const BorderSide(color: Color(0xFFE2D9FF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size.fromHeight(42),
                          ),
                          child: Text(
                            'Pay with NetBanking / Debit / Credit card instead',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        'UPI is processed by our UPI gateway. Cards / NetBanking are processed by Easebuzz.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF9CA3AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top > 0 ? 14 : 16, 20, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9747FF), Color(0xFF7C3AED), Color(0xFF5B2B99)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAY USING',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.amountLabel ?? _money(widget.cashAmount),
                  style: GoogleFonts.poppins(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform fee is added per method. Order ${widget.orderNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appButton(_UpiApp app, (Color, Color)? accent, double? upiFee) {
    final bg = accent?.$1 ?? const Color(0xFFF7F2FF);
    final fg = accent?.$2 ?? const Color(0xFF5B2B99);
    return GestureDetector(
      onTap: _starting ? null : () => _handleApp(app),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2D9FF)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Text(
                app.label.substring(0, 1),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B1E78),
                    ),
                  ),
                  Text(
                    _total(upiFee) ?? 'Fee at checkout',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wideRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
    bool dashed = false,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFF7F2FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dashed ? const Color(0xFFD9CBFF) : const Color(0xFFE2D9FF),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF5B2B99)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5B2B99),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _cardMethodRow(PaymentMethodFee method, double fee) {
    return GestureDetector(
      onTap: _starting
          ? null
          : () {
              Navigator.of(context).maybePop();
              widget.onCardMethod(method.code);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE2D9FF)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF7F2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.credit_card, size: 16, color: Color(0xFF5B2B99)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF3B1E78),
                    ),
                  ),
                  Text(
                    'Fee ${_money(fee)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _money(widget.cashAmount + fee),
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF5B2B99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
