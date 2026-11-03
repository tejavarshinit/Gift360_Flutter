import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/payment/presentation/providers/payment_provider.dart';

/// Phases of the Juspay UPI-intent flow (React `UpiIntentPhase`).
enum _UpiPhase { idle, initiating, awaiting, confirming, paid, failed, expired }

/// Bottom sheet for the Juspay UPI-intent flow: start -> open UPI app -> poll
/// the backend until it reports a terminal state. The client only DISPLAYS
/// what the backend reports — it never decides a payment is done and never
/// builds the upi:// deeplink itself.
///
/// Ported from React `components/UpiIntentSheet.tsx` +
/// `hooks/useUpiIntentPayment.ts` (minus the iOS-only app grid/QR: Flutter
/// Android/web launch the system UPI chooser directly).
class UpiIntentSheet extends ConsumerStatefulWidget {
  final String orderNumber;
  final String? amountLabel;
  final VoidCallback onClose;
  final void Function(String orderNumber)? onPaid;

  /// Escape hatch: run the regular hosted checkout for the same order -
  /// shown when the UPI-intent gateway is unavailable.
  final VoidCallback? onFallbackToOtherMethods;

  /// Already-created intent (the "Pay using" chooser creates it so it can
  /// launch the app the customer actually picked). When null, the sheet
  /// creates + launches the intent itself (legacy direct flow).
  final Map<String, dynamic>? initialIntent;

  /// When paying by QR, show the backend deeplink as a QR in the modal.
  final String? qrValue;

  /// "View my vouchers" on success (defaults to [onClose]).
  final VoidCallback? onViewOrders;

  /// "Leave for now" while the payment is still pending.
  final VoidCallback? onLeavePending;

  const UpiIntentSheet({
    super.key,
    required this.orderNumber,
    this.amountLabel,
    required this.onClose,
    this.onPaid,
    this.onFallbackToOtherMethods,
    this.initialIntent,
    this.qrValue,
    this.onViewOrders,
    this.onLeavePending,
  });

  @override
  ConsumerState<UpiIntentSheet> createState() => _UpiIntentSheetState();
}

class _UpiIntentSheetState extends ConsumerState<UpiIntentSheet>
    with WidgetsBindingObserver {
  Duration get _pollInterval =>
      Duration(milliseconds: AppConfig.upiPollIntervalMs);

  _UpiPhase _phase = _UpiPhase.idle;
  Map<String, dynamic>? _intent;
  String? _error;
  bool _copied = false;
  Timer? _pollTimer;
  bool _stopped = false;

  /// Close-check state (React PaymentProcessingModal): closing while pending
  /// re-checks the backend and offers "still pending" actions.
  bool _pendingPrompt = false;
  bool _checking = false;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  String? get _deeplink => _intent?['deeplink']?.toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final preset = widget.initialIntent;
    if (preset != null) {
      _intent = preset;
      _phase = _UpiPhase.awaiting;
      _schedulePoll();
      _startElapsedTimer();
    } else {
      _start();
    }
  }

  @override
  void dispose() {
    _stopped = true;
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _stopped) return;
      if (_phase == _UpiPhase.paid ||
          _phase == _UpiPhase.failed ||
          _phase == _UpiPhase.expired) {
        t.cancel();
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  String get _elapsedLabel {
    final capped = _elapsedSeconds > 59 * 60 + 59
        ? 59 * 60 + 59
        : _elapsedSeconds;
    final mm = (capped ~/ 60).toString().padLeft(2, '0');
    final ss = (capped % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from the UPI app: re-check immediately (React's return listener
    // / appStateChange resume).
    if (state == AppLifecycleState.resumed) _checkNow();
  }

  Future<void> _start() async {
    if (widget.orderNumber.isEmpty) return;
    _stopped = false;
    _pollTimer?.cancel();
    setState(() {
      _error = null;
      _phase = _UpiPhase.initiating;
    });
    try {
      final api = ref.read(orderApiProvider);
      final response = await api.createUpiIntent(widget.orderNumber);
      final deeplink = response['deeplink']?.toString() ?? '';
      if (deeplink.isEmpty) {
        throw Exception(
          response['responseMessage']?.toString() ??
              'Unable to start the UPI payment.',
        );
      }
      if (!mounted) return;
      setState(() {
        _intent = response;
        _phase = _UpiPhase.awaiting;
        _pendingPrompt = false;
      });
      _startElapsedTimer();
      // Launch the backend deeplink (the system UPI chooser picks the app).
      await _launchUpi(deeplink);
      _schedulePoll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _phase = _UpiPhase.failed;
      });
    }
  }

  Future<bool> _launchUpi(String deeplink) async {
    try {
      return await launchUrl(
        Uri.parse(deeplink),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  void _schedulePoll() {
    if (_stopped) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(_pollInterval, () async {
      if (_stopped || !mounted) return;
      final done = await _pollOnce();
      if (!mounted || _stopped || done) return;
      if (_phase == _UpiPhase.awaiting)
        setState(() => _phase = _UpiPhase.confirming);
      _schedulePoll();
    });
  }

  Future<bool> _pollOnce() async {
    try {
      final api = ref.read(orderApiProvider);
      final status = await api.fetchUpiIntentStatus(widget.orderNumber);
      return _applyStatus(status);
    } catch (_) {
      return false; // transient — keep polling
    }
  }

  bool _applyStatus(Map<String, dynamic> status) {
    final paid =
        status['paid'] == true ||
        status['status']?.toString().toUpperCase() == 'SUCCESS';
    if (paid) {
      _pollTimer?.cancel();
      setState(() => _phase = _UpiPhase.paid);
      widget.onPaid?.call(widget.orderNumber);
      return true;
    }
    final state = status['status']?.toString().toUpperCase() ?? '';
    if (state == 'FAILED') {
      _pollTimer?.cancel();
      setState(() {
        _error =
            status['message']?.toString() ?? 'The payment was not completed.';
        _phase = _UpiPhase.failed;
      });
      return true;
    }
    if (state == 'EXPIRED') {
      _pollTimer?.cancel();
      setState(() {
        _error =
            status['message']?.toString() ??
            'The UPI payment request expired. Please try again.';
        _phase = _UpiPhase.expired;
      });
      return true;
    }
    return false;
  }

  Future<void> _checkNow() async {
    if (_stopped) return;
    if (_phase == _UpiPhase.paid ||
        _phase == _UpiPhase.failed ||
        _phase == _UpiPhase.expired) {
      return;
    }
    if (_phase == _UpiPhase.awaiting)
      setState(() => _phase = _UpiPhase.confirming);
    final done = await _pollOnce();
    if (done || !mounted) return;
    setState(() => _phase = _UpiPhase.awaiting);
    _schedulePoll();
  }

  /// React's handleCheck: poll once with a spinner, no state churn.
  Future<void> _handleCheckStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await _checkNow();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// React's handleRequestClose: re-check the backend before leaving; if it is
  /// still pending, show the "still pending" choices instead of closing.
  Future<void> _requestClose() async {
    if (_phase == _UpiPhase.paid ||
        _phase == _UpiPhase.failed ||
        _phase == _UpiPhase.expired) {
      _requestCloseTerminal();
      return;
    }
    setState(() => _checking = true);
    try {
      final done = await _pollOnce();
      if (!mounted) return;
      if (done) return;
      setState(() => _pendingPrompt = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _requestCloseTerminal() {
    // Failed/expired close for good; paid goes to "View my vouchers".
    if (_phase == _UpiPhase.paid) {
      (widget.onViewOrders ?? _close)();
      return;
    }
    _close();
  }

  /// "X" / "Leave for now" while pending: stop polling and go back to the
  /// "Pay using" sheet behind this modal (the order keeps updating server-side).
  void _leavePending() {
    _stopped = true;
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    _pendingPrompt = false;
    if (mounted) Navigator.of(context).pop();
  }

  void _keepWaiting() {
    setState(() {
      _pendingPrompt = false;
      _phase = _UpiPhase.awaiting;
    });
    _schedulePoll();
  }

  Future<void> _reopen() async {
    final link = _deeplink;
    if (link == null) return;
    final opened = await _launchUpi(link);
    if (!opened && mounted) {
      setState(() => _error = 'Could not open a UPI app. Copy the link below.');
    }
  }

  void _close() {
    _stopped = true;
    _pollTimer?.cancel();
    _elapsedTimer?.cancel();
    widget.onClose();
  }

  Future<void> _copyLink() async {
    final link = _deeplink;
    if (link == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      setState(() => _copied = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      /* clipboard unavailable */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final String title;
    if (_phase == _UpiPhase.paid) {
      title = 'Payment successful';
    } else if (_phase == _UpiPhase.failed || _phase == _UpiPhase.expired) {
      title = 'Payment not completed';
    } else {
      title = 'Complete payment in your UPI app';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9747FF), Color(0xFF7C3AED), Color(0xFF5B2B99)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PAY WITH UPI',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order ${widget.orderNumber}'
                  '${widget.amountLabel != null ? ' \u00b7 ${widget.amountLabel}' : ''}',
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
            onTap: () {
              if (_phase == _UpiPhase.paid ||
                  _phase == _UpiPhase.failed ||
                  _phase == _UpiPhase.expired) {
                _requestCloseTerminal();
              } else if (_pendingPrompt) {
                _leavePending();
              } else {
                _requestClose();
              }
            },
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

  Widget _buildBody() {
    final waiting =
        _phase != _UpiPhase.paid &&
        _phase != _UpiPhase.failed &&
        _phase != _UpiPhase.expired;
    if (waiting && _pendingPrompt) return _buildPendingPrompt();
    switch (_phase) {
      case _UpiPhase.idle:
      case _UpiPhase.initiating:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF7C3AED),
                ),
              ),
            ),
            Text(
              'Starting your UPI payment\u2026',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Please keep this screen open.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            SizedBox(height: 8),
            Text(
              'Do not close this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            ),
          ],
        );
      case _UpiPhase.awaiting:
      case _UpiPhase.confirming:
        return _buildAwaiting();
      case _UpiPhase.paid:
        return _buildPaid();
      case _UpiPhase.failed:
      case _UpiPhase.expired:
        return _buildFailed();
    }
  }

  Widget _buildAwaiting() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.qrValue != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE9DFFF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: QrImageView(
                data: widget.qrValue!,
                size: 156,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF3B1E78),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF3B1E78),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Scan with any UPI app',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B2B99),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2FF),
              border: Border.all(color: const Color(0xFFE9DFFF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.smartphone,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pay in the UPI app that just opened, then come back here '
                    '\u2014 we confirm the payment automatically.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      height: 1.4,
                      color: const Color(0xFF4C1D95),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _reopen,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                'Reopen UPI app',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _phase == _UpiPhase.confirming
                    ? 'Confirming payment\u2026'
                    : 'Waiting for you to finish in your UPI app',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: _handleCheckStatus,
              child: Text(
                'Check status',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F2FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: Color(0xFF5B2B99),
                ),
                const SizedBox(width: 4),
                Text(
                  _elapsedLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5B2B99),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _copyLink,
          icon: Icon(
            _copied ? Icons.check : Icons.copy,
            size: 14,
            color: _copied ? const Color(0xFF059669) : const Color(0xFF7C3AED),
          ),
          label: Text(
            _copied
                ? 'Payment link copied'
                : 'Copy payment link (open in any UPI app)',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7C3AED),
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFD9CBFF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: _checking ? null : _requestClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9747FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _checking ? 'Checking\u2026' : 'Close',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Do not close this screen until you see the confirmation.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  /// React's "Payment still pending" state after the user tries to close.
  Widget _buildPendingPrompt() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time,
              size: 28,
              color: Color(0xFFD97706),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Payment still pending',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "We haven't received the gateway confirmation yet. If the money was "
          'debited, your order will update automatically \u2014 you can leave this '
          'screen safely.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.4,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: OutlinedButton(
            onPressed: _keepWaiting,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B2B99),
              side: const BorderSide(color: Color(0xFFE2D9FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Keep waiting',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _leavePending,
          child: Text(
            'Leave for now',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 42, color: Color(0xFF10B981)),
        const SizedBox(height: 10),
        const Text(
          'Payment received',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your vouchers are being issued. You can track them in My Orders.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: widget.onViewOrders ?? _close,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9747FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'View my vouchers',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            border: Border.all(color: const Color(0xFFFECACA)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                size: 16,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error ??
                      'The payment was not completed. You have not been charged.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.4,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_deeplink != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9747FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        if (widget.onFallbackToOtherMethods != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: widget.onFallbackToOtherMethods,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B2B99),
                side: const BorderSide(color: Color(0xFFE2D9FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Pay with NetBanking / Debit / Credit card instead',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: OutlinedButton.icon(
            onPressed: _checking ? null : _handleCheckStatus,
            icon: const Icon(Icons.refresh, size: 15),
            label: Text(
              'Check status',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF5B2B99),
              side: const BorderSide(color: Color(0xFFE2D9FF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: OutlinedButton(
            onPressed: _close,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Close',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
