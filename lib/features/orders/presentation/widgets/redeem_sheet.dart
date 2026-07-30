import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/gifting/presentation/providers/gifting_provider.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';

enum _RedeemStep { details, steps }

enum _CheckState { idle, checking, used, active, error }

/// Shows the redeem bottom sheet for a paid order and resolves with `true`
/// once the buyer has confirmed the voucher(s) were used.
Future<bool?> showRedeemSheet(
  BuildContext context, {
  required List<VoucherView> vouchers,
  required String brandName,
  String? redeemSteps,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RedeemSheet(vouchers: vouchers, brandName: brandName, redeemSteps: redeemSteps),
  );
}

/// Port of the `RedeemSheet` function component in Orders.tsx.
class RedeemSheet extends ConsumerStatefulWidget {
  final List<VoucherView> vouchers;
  final String brandName;
  final String? redeemSteps;

  const RedeemSheet({
    super.key,
    required this.vouchers,
    required this.brandName,
    this.redeemSteps,
  });

  @override
  ConsumerState<RedeemSheet> createState() => _RedeemSheetState();
}

class _RedeemSheetState extends ConsumerState<RedeemSheet> {
  _RedeemStep _step = _RedeemStep.details;
  _CheckState _checkState = _CheckState.idle;
  final Map<String, String> _balances = {};

  Future<void> _handleCheck() async {
    if (widget.vouchers.isEmpty) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() => _checkState = _CheckState.checking);
    try {
      final api = ref.read(giftingApiProvider);
      final entries = await Future.wait(widget.vouchers.map((v) async {
        final r = await api.checkVoucherBalance(v.cardNumber);
        return MapEntry(v.cardNumber, r['balance']?.toString() ?? '0');
      }));
      if (!mounted) return;
      final allZero =
          entries.every((e) => (double.tryParse(e.value) ?? 0) == 0);
      setState(() {
        _balances
          ..clear()
          ..addEntries(entries);
        _checkState = allZero ? _CheckState.used : _CheckState.active;
      });
      if (allZero) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _checkState = _CheckState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSteps = widget.redeemSteps != null && widget.redeemSteps!.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                if (hasSteps) ...[
                  _buildTabs(),
                  const SizedBox(height: 20),
                ],
                _step == _RedeemStep.details ? _buildDetails() : _buildHowToRedeem(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(child: _tabButton('Voucher Details', _RedeemStep.details)),
          Expanded(child: _tabButton('How to Redeem', _RedeemStep.steps)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _RedeemStep step) {
    final selected = _step == step;
    return GestureDetector(
      onTap: () => setState(() => _step = step),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFF7B5CFF), Color(0xFF5A4BFF)])
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : const Color(0xFF888888))),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.brandName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        ...List.generate(widget.vouchers.length, (i) {
          final v = widget.vouchers[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _voucherDetailCard(v, i),
          );
        }),
        if (widget.vouchers.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '⏳ Vouchers are being generated. Please refresh in a moment.',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
            ),
          ),
        if (_checkState == _CheckState.used) _statusBanner(
          icon: Icons.check_circle,
          color: const Color(0xFF16A34A),
          bg: const Color(0xFFF0FDF4),
          border: const Color(0xFFBBF7D0),
          title: 'Voucher confirmed used! Moving to Redeemed...',
        ),
        if (_checkState == _CheckState.active) _statusBanner(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFD97706),
          bg: const Color(0xFFFFFBEB),
          border: const Color(0xFFFDE68A),
          title: 'Voucher not yet used',
          subtitle: 'This voucher still has balance. Please use it at the merchant first.',
        ),
        if (_checkState == _CheckState.error) _statusBanner(
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFF888888),
          bg: const Color(0xFFF3F4F6),
          border: const Color(0xFFE5E7EB),
          title: 'Balance check unavailable',
          subtitle: "Cannot verify automatically. Confirm manually if you've used this voucher at the merchant.",
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  foregroundColor: Colors.black87,
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildPrimaryAction()),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryAction() {
    if (_checkState == _CheckState.error) {
      return ElevatedButton(
        onPressed: () => Navigator.of(context).pop(true),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: const Color(0xFFFF8AA0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Mark as Redeemed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }
    if (_checkState == _CheckState.active) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Not Used Yet', style: TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    final disabled = _checkState == _CheckState.checking || _checkState == _CheckState.used;
    return ElevatedButton(
      onPressed: disabled ? null : _handleCheck,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: const Color(0xFF7B5CFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _checkState == _CheckState.checking
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 8),
                Text('Checking...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            )
          : const Text("I've Used This Voucher",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBanner({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required String title,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bg, border: Border.all(color: border), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _voucherDetailCard(VoucherView v, int index) {
    final bal = _balances[v.cardNumber];
    final isUsed = bal != null && (double.tryParse(bal) ?? -1) == 0;
    final isLocked = v.isGift;
    final isRevealed = v.isScratched;

    Widget badge;
    if (isLocked) {
      badge = _pill('🎁 Gifted', bg: const Color(0xFFFFE4E6), fg: const Color(0xFFBE123C));
    } else if (bal != null) {
      badge = isUsed
          ? _pill('✓ USED', bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D))
          : _pill('Balance: ₹$bal', bg: const Color(0xFFFEF3C7), fg: const Color(0xFF92400E));
    } else {
      badge = _pill('₹${v.amount}', bg: const Color(0x1A7B5CFF), fg: const Color(0xFF7B5CFF));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Voucher ${widget.vouchers.length > 1 ? index + 1 : ''}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF888888))),
              badge,
            ],
          ),
          const SizedBox(height: 10),
          if (isLocked)
            _mutedNotice("This voucher was gifted — the code was sent only to the recipient.")
          else if (!isRevealed)
            _mutedNotice('Reveal this voucher from "View Vouchers" first (choose "Use myself").')
          else ...[
            _codeBox('Card Number', v.cardNumber),
            if (v.cardPin.isNotEmpty) ...[
              const SizedBox(height: 8),
              _codeBox('PIN', v.cardPin),
            ],
          ],
          if (v.expiryDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text.rich(TextSpan(
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
              children: [
                const TextSpan(text: 'Expires: '),
                TextSpan(
                    text: v.expiryDate,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
              ],
            )),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, {required Color bg, required Color fg}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
      );

  Widget _mutedNotice(String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: Color(0xFF888888)),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888)))),
          ],
        ),
      );

  Widget _codeBox(String label, String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card, size: 12, color: Color(0xFF7B5CFF)),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
              ],
            ),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    fontFamily: 'monospace')),
          ],
        ),
      );

  Widget _buildHowToRedeem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.menu_book_outlined, size: 18, color: Color(0xFF7B5CFF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('How to Redeem at ${widget.brandName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(widget.redeemSteps ?? '',
            style: const TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, color: Color(0xFF888888))),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => setState(() => _step = _RedeemStep.details),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF7B5CFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Back to Voucher Details',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
