import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/gifting/presentation/providers/gifting_provider.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';
import 'package:gift360/features/orders/presentation/widgets/scratch_gate.dart';

class ScratchCard extends ConsumerStatefulWidget {
  final VoucherView voucher;
  final String clientId;
  final String orderNumber;
  final int index;
  final ValueChanged<VoucherState>? onStateChange;

  const ScratchCard({
    super.key,
    required this.voucher,
    required this.clientId,
    required this.orderNumber,
    required this.index,
    this.onStateChange,
  });

  @override
  ConsumerState<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends ConsumerState<ScratchCard> {
  late VoucherState _voucherState;

  @override
  void initState() {
    super.initState();
    _voucherState = widget.voucher.initialState;
  }

  @override
  void didUpdateWidget(covariant ScratchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voucher.initialState != widget.voucher.initialState) {
      _voucherState = widget.voucher.initialState;
    }
  }

  void _showSnack(String title, String? description, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFFB91C1C) : const Color(0xFF1E1335),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (description != null && description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object err) {
    if (err is DioException) {
      final data = err.response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (err.error is String) return err.error as String;
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _confirmScratch() async {
    try {
      final api = ref.read(giftingApiProvider);
      final result = await api.scratchVoucher({
        'clientId': widget.clientId,
        'orderItemId': widget.voucher.orderItemId,
      });
      if (!mounted) return;
      setState(() => _voucherState = VoucherState.scratched);
      widget.onStateChange?.call(VoucherState.scratched);
      _showSnack('Voucher revealed! 🎉', result['message']?.toString());
    } on DioException catch (e) {
      final message = _errorMessage(e);
      if (e.response?.statusCode == 409) {
        _showSnack('Already used', message, isError: true);
        final next = message.contains('gifted') ? VoucherState.gifted : VoucherState.scratched;
        if (mounted) setState(() => _voucherState = next);
        widget.onStateChange?.call(next);
      } else {
        _showSnack('Could not reveal voucher', message, isError: true);
      }
      rethrow;
    } catch (e) {
      _showSnack('Could not reveal voucher', 'Something went wrong. Please try again.', isError: true);
      rethrow;
    }
  }

  Future<void> _confirmGift({
    String? recipientEmail,
    String? recipientMobile,
    required DeliveryChannel deliveryChannel,
    String? personalMessage,
    String? senderName,
    String? mediaUrl,
  }) async {
    try {
      final api = ref.read(giftingApiProvider);
      final result = await api.giftVoucher({
        'clientId': widget.clientId,
        'orderItemId': widget.voucher.orderItemId,
        if (recipientEmail != null) 'recipientEmail': recipientEmail,
        if (senderName != null) 'senderName': senderName,
        if (personalMessage != null) 'personalMessage': personalMessage,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (recipientMobile != null) 'recipientMobile': recipientMobile,
        'deliveryChannel': deliveryChannel.apiValue,
      });
      if (!mounted) return;
      setState(() => _voucherState = VoucherState.gifted);
      widget.onStateChange?.call(VoucherState.gifted);
      _showSnack('Voucher gifted! 🎁', result['message']?.toString());
    } on DioException catch (e) {
      final message = _errorMessage(e);
      if (e.response?.statusCode == 409) {
        _showSnack('Already used', message, isError: true);
        final next = message.contains('scratched') ? VoucherState.scratched : VoucherState.gifted;
        if (mounted) setState(() => _voucherState = next);
        widget.onStateChange?.call(next);
      } else {
        _showSnack('Could not gift voucher', message, isError: true);
      }
      rethrow;
    } catch (e) {
      _showSnack('Could not gift voucher', 'Something went wrong. Please try again.', isError: true);
      rethrow;
    }
  }

  Future<String?> _uploadMedia(XFile file, bool isVideo) async {
    final api = ref.read(giftingApiProvider);
    final contentType = _guessContentType(file.name, isVideo);
    final uploadInfo = await api.getMediaUploadUrl(widget.voucher.orderItemId, contentType);
    final uploadUrl = uploadInfo['uploadUrl']?.toString();
    final cdnUrl = uploadInfo['cdnUrl']?.toString();
    if (uploadUrl == null) return null;
    final Uint8List bytes = await file.readAsBytes();
    final plainDio = Dio();
    await plainDio.put(
      uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );
    return cdnUrl;
  }

  String _guessContentType(String name, bool isVideo) {
    final lower = name.toLowerCase();
    if (isVideo) {
      if (lower.endsWith('.mov')) return 'video/quicktime';
      if (lower.endsWith('.webm')) return 'video/webm';
      return 'video/mp4';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _openGate() {
    if (_voucherState != VoucherState.pending) return;
    final displayName = widget.voucher.brandName.isNotEmpty
        ? widget.voucher.brandName
        : 'Card #${widget.index + 1}';
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ScratchGate(
        brandName: displayName,
        voucherAmount: widget.voucher.amount,
        onConfirmScratch: _confirmScratch,
        onConfirmGift: _confirmGift,
        onUploadMedia: _uploadMedia,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.voucher.brandName.isNotEmpty ? widget.voucher.brandName : 'Card #${widget.index + 1}';

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E1335), Color(0xFF2D1B69)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: _voucherState == VoucherState.scratched
                ? Border.all(color: const Color(0x99FBBF24), width: 2)
                : _voucherState == VoucherState.gifted
                    ? Border.all(color: const Color(0x66FCD34D), width: 2)
                    : null,
            boxShadow: const [
              BoxShadow(color: Color(0x4D6E66E7), blurRadius: 6, offset: Offset(4, 4)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(blurRadius: 6, color: Colors.black.withValues(alpha: 0.2)),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFF92400E), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gift Voucher',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xB3FCD34D))),
                        Text(displayName,
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Value',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xB3FCD34D))),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFDAA520), Color(0xFFFFD700)],
                        ).createShader(bounds),
                        child: Text('₹${widget.voucher.amount}',
                            style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailBox(
                icon: Icons.credit_card,
                label: 'Card Number',
                value: _voucherState == VoucherState.scratched ? widget.voucher.cardNumber : '••••  ••••  ••••',
              ),
              const SizedBox(height: 10),
              _detailBox(
                icon: Icons.lock,
                label: 'Card PIN',
                value: _voucherState == VoucherState.scratched ? widget.voucher.cardPin : '••••••',
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: const Color(0xFFFCD34D).withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expires',
                              style: GoogleFonts.poppins(
                                  fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFFFCD34D).withValues(alpha: 0.5))),
                          Text(widget.voucher.expiryDate,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                  _statusBadge(),
                ],
              ),
            ],
          ),
        ),

        // Scratch overlay (PENDING only)
        if (_voucherState == VoucherState.pending)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: _openGate,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D1B69), Color(0xFF4A1F8E), Color(0xFF6D28D9)],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('✨ Scratch to Reveal',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        SizedBox(height: 6),
                        Text('Tap here to use or gift',
                            style: TextStyle(color: Color(0xCCFFD700), fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Gifted overlay
        if (_voucherState == VoucherState.gifted)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1E1335).withValues(alpha: 0.95),
                      const Color(0xFF2D1B69).withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x4DF59E0B), blurRadius: 12),
                          ],
                        ),
                        child: const Icon(Icons.card_giftcard, color: Color(0xFF92400E), size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text('Voucher Gifted',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Sent to the recipient',
                          style: GoogleFonts.poppins(color: const Color(0x99FCD34D), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Revealed celebration overlay (SCRATCHED)
        if (_voucherState == VoucherState.scratched)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFDAA520)]),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text('🎉 Revealed!',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
            ),
          ),
      ],
    );
  }

  Widget _detailBox({required IconData icon, required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFFFCD34D)),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: const Color(0xB3FCD34D), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ).copyWith(fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    switch (_voucherState) {
      case VoucherState.scratched:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFDAA520)]),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(blurRadius: 6, color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
            ],
          ),
          child: Text('✓ Revealed',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF92400E))),
        );
      case VoucherState.gifted:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFCA8A04)]),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.send, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text('Gifted',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        );
      case VoucherState.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text('Active',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFFCD34D))),
        );
    }
  }
}
