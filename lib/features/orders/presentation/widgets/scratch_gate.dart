import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';

typedef ConfirmScratchCallback = Future<void> Function();

typedef ConfirmGiftCallback = Future<void> Function({
  String? recipientEmail,
  String? recipientMobile,
  required DeliveryChannel deliveryChannel,
  String? personalMessage,
  String? senderName,
  String? mediaUrl,
});

/// Uploads the picked file and returns the CDN url, or null on failure.
typedef MediaUploadCallback = Future<String?> Function(XFile file, bool isVideo);

enum _GateStep { choice, giftForm }

/// Port of `ScratchGate.tsx` — the modal shown when a buyer taps a
/// PENDING scratch card. Offers "Use myself" (reveal) or "Gift to
/// someone" (email / WhatsApp / both, with an optional personal
/// message + photo/video).
class ScratchGate extends StatefulWidget {
  final String brandName;
  final String voucherAmount;
  final ConfirmScratchCallback onConfirmScratch;
  final ConfirmGiftCallback onConfirmGift;
  final MediaUploadCallback onUploadMedia;

  const ScratchGate({
    super.key,
    required this.brandName,
    required this.voucherAmount,
    required this.onConfirmScratch,
    required this.onConfirmGift,
    required this.onUploadMedia,
  });

  @override
  State<ScratchGate> createState() => _ScratchGateState();
}

class _ScratchGateState extends State<ScratchGate> {
  _GateStep _step = _GateStep.choice;
  DeliveryChannel _channel = DeliveryChannel.whatsapp;

  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String? _emailError;
  String? _mobileError;

  XFile? _mediaFile;
  Uint8List? _mediaPreviewBytes;
  bool _mediaIsVideo = false;
  String? _mediaError;
  bool _isUploadingMedia = false;

  bool _isScratchLoading = false;
  bool _isGiftLoading = false;

  bool get _isLoading => _isScratchLoading || _isGiftLoading || _isUploadingMedia;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _senderCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool _validateEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  bool _validateMobile(String v) =>
      RegExp(r'^\d{10,15}$').hasMatch(v.replaceAll(RegExp(r'[\s\-+]'), ''));

  bool _validate() {
    String? emailError;
    String? mobileError;
    if (_channel == DeliveryChannel.email || _channel == DeliveryChannel.both) {
      if (_emailCtrl.text.trim().isEmpty) {
        emailError = 'Email is required.';
      } else if (!_validateEmail(_emailCtrl.text)) {
        emailError = 'Enter a valid email.';
      }
    }
    if (_channel == DeliveryChannel.whatsapp || _channel == DeliveryChannel.both) {
      if (_mobileCtrl.text.trim().isEmpty) {
        mobileError = 'Mobile number is required.';
      } else if (!_validateMobile(_mobileCtrl.text)) {
        mobileError = 'Enter a valid 10–15 digit mobile number (e.g. 919876543210).';
      }
    }
    setState(() {
      _emailError = emailError;
      _mobileError = mobileError;
    });
    return emailError == null && mobileError == null;
  }

  Future<void> _pickMedia(bool video) async {
    setState(() => _mediaError = null);
    final picker = ImagePicker();
    try {
      final XFile? file = video
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
        setState(() => _mediaError = 'File must be under 20 MB.');
        return;
      }
      setState(() {
        _mediaFile = file;
        _mediaIsVideo = video;
        _mediaPreviewBytes = video ? null : bytes;
      });
    } catch (_) {
      setState(() => _mediaError = 'Could not read the selected file.');
    }
  }

  void _clearMedia() {
    setState(() {
      _mediaFile = null;
      _mediaPreviewBytes = null;
      _mediaIsVideo = false;
      _mediaError = null;
    });
  }

  Future<void> _handleScratchConfirm() async {
    setState(() => _isScratchLoading = true);
    bool success = true;
    try {
      await widget.onConfirmScratch();
    } catch (_) {
      success = false;
    } finally {
      if (mounted) setState(() => _isScratchLoading = false);
    }
    if (mounted && success) Navigator.of(context).pop();
  }

  Future<void> _handleGiftConfirm() async {
    if (!_validate()) return;

    String? cdnUrl;
    if (_mediaFile != null) {
      setState(() => _isUploadingMedia = true);
      try {
        cdnUrl = await widget.onUploadMedia(_mediaFile!, _mediaIsVideo);
      } catch (_) {
        setState(() =>
            _mediaError = 'Media upload failed — gift will send without the photo/video.');
      } finally {
        if (mounted) setState(() => _isUploadingMedia = false);
      }
    }

    final mobile = _mobileCtrl.text.replaceAll(RegExp(r'[\s\-+]'), '');
    setState(() => _isGiftLoading = true);
    bool success = true;
    try {
      await widget.onConfirmGift(
        recipientEmail: (_channel == DeliveryChannel.email || _channel == DeliveryChannel.both)
            ? _emailCtrl.text.trim()
            : null,
        recipientMobile:
            (_channel == DeliveryChannel.whatsapp || _channel == DeliveryChannel.both)
                ? (mobile.isEmpty ? null : mobile)
                : null,
        deliveryChannel: _channel,
        personalMessage: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
        senderName: _senderCtrl.text.trim().isEmpty ? null : _senderCtrl.text.trim(),
        mediaUrl: cdnUrl,
      );
    } catch (_) {
      success = false;
    } finally {
      if (mounted) setState(() => _isGiftLoading = false);
    }
    if (mounted && success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _step == _GateStep.choice ? _buildChoiceStep() : _buildGiftForm(),
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
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF9747FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _step == _GateStep.choice ? 'What would you like to do?' : 'Gift this voucher',
            style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            _step == _GateStep.choice
                ? '${widget.brandName} · ₹${widget.voucherAmount}'
                : 'Personalise your gift below.',
            style: TextStyle(color: Colors.black.withValues(alpha: 0.6), fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── ChoiceStep ─────────────────────────────────────────────────────────
  Widget _buildChoiceStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChoiceButton(
          onTap: _isLoading ? null : _handleScratchConfirm,
          gradient: const LinearGradient(colors: [AppColors.goldLight, AppColors.gold]),
          icon: _isScratchLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF78350F)))
              : const Icon(Icons.auto_awesome, color: Color(0xFF78350F)),
          title: 'Use myself',
          subtitle: 'Reveal the code now for personal use',
          titleColor: const Color(0xFF78350F),
          subtitleColor: const Color(0xB378350F),
        ),
        const SizedBox(height: 12),
        _ChoiceButton(
          onTap: _isLoading ? null : () => setState(() => _step = _GateStep.giftForm),
          border: Border.all(color: const Color(0x4D9747FF), width: 2),
          icon: const Icon(Icons.card_giftcard, color: Color(0xFF9747FF)),
          iconBg: const Color(0x1A9747FF),
          title: 'Gift to someone',
          subtitle: 'Send via email, WhatsApp, or both',
          titleColor: const Color(0xFF1E293B),
          subtitleColor: const Color(0xFF64748B),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: const Color(0xFF64748B),
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Decide later', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── GiftFormStep ───────────────────────────────────────────────────────
  Widget _buildGiftForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Send via', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
        const SizedBox(height: 8),
        _buildChannelPicker(),
        const SizedBox(height: 16),
        if (_channel == DeliveryChannel.whatsapp || _channel == DeliveryChannel.both) ...[
          _buildLabel('WhatsApp number', required: true, hint: '(with country code, e.g. 919876543210)'),
          const SizedBox(height: 6),
          TextField(
            controller: _mobileCtrl,
            enabled: !_isLoading,
            keyboardType: TextInputType.phone,
            decoration: _inputDecoration(hintText: '919876543210', icon: Icons.chat_bubble, iconColor: const Color(0xFF10B981), errorText: _mobileError),
          ),
          const SizedBox(height: 16),
        ],
        if (_channel == DeliveryChannel.email || _channel == DeliveryChannel.both) ...[
          _buildLabel('Email address', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _emailCtrl,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration(hintText: 'friend@example.com', icon: Icons.email_outlined, errorText: _emailError),
          ),
          const SizedBox(height: 16),
        ],
        _buildLabel('Your name', hint: '(shown on the gift)'),
        const SizedBox(height: 6),
        TextField(
          controller: _senderCtrl,
          enabled: !_isLoading,
          maxLength: 100,
          decoration: _inputDecoration(hintText: 'e.g. Priya', icon: Icons.person_outline),
        ),
        const SizedBox(height: 8),
        _buildLabel('Personal message', hint: '(optional)'),
        const SizedBox(height: 6),
        TextField(
          controller: _messageCtrl,
          enabled: !_isLoading,
          maxLength: 500,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(hintText: 'Add a note…'),
        ),
        const SizedBox(height: 8),
        _buildLabel('Add a photo or video', hint: '(optional · max 20 MB)'),
        const SizedBox(height: 8),
        _buildMediaPicker(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFFDE68A)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Once gifted, the voucher code will be sent only to the recipient. You won't be able to view or use it.",
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                          _step = _GateStep.choice;
                          _emailError = null;
                          _mobileError = null;
                        }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleGiftConfirm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF78350F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isGiftLoading || _isUploadingMedia
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF78350F))),
                          const SizedBox(width: 8),
                          Text(_isUploadingMedia ? 'Uploading…' : 'Sending…',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.card_giftcard, size: 18),
                          SizedBox(width: 8),
                          Text('Send Gift', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {bool required = false, String? hint}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black),
        children: [
          TextSpan(text: text),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: Color(0xFFE11D48))),
          if (hint != null)
            TextSpan(
              text: ' $hint',
              style: const TextStyle(fontWeight: FontWeight.w400, color: Colors.black54, fontSize: 12),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {String? hintText, IconData? icon, Color? iconColor, String? errorText}) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      prefixIcon: icon != null ? Icon(icon, size: 18, color: iconColor ?? Colors.black38) : null,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF9747FF), width: 1.5),
      ),
    );
  }

  Widget _buildChannelPicker() {
    final opts = [
      (DeliveryChannel.whatsapp, 'WhatsApp', 'Instant delivery', Icons.chat_bubble, const Color(0xFF10B981)),
      (DeliveryChannel.email, 'Email', 'Rich gift card', Icons.email_outlined, const Color(0xFF9747FF)),
      (DeliveryChannel.both, 'Both', 'Maximum reach', Icons.dynamic_feed, const Color(0xFFF59E0B)),
    ];
    return Row(
      children: opts.map((o) {
        final selected = _channel == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: _isLoading ? null : () => setState(() => _channel = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0x149747FF) : Colors.white,
                  border: Border.all(color: selected ? const Color(0xFF9747FF) : const Color(0xFFE2E8F0), width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(o.$4, size: 18, color: o.$5),
                    const SizedBox(height: 4),
                    Text(o.$2,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? const Color(0xFF9747FF) : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(o.$3,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMediaPicker() {
    if (_mediaFile != null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (_mediaPreviewBytes != null)
              Image.memory(_mediaPreviewBytes!, width: double.infinity, height: 140, fit: BoxFit.cover)
            else
              Container(
                width: double.infinity,
                height: 140,
                color: const Color(0xFFF1F5F9),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam, color: Color(0xFF9747FF)),
                    const SizedBox(height: 6),
                    Text(_mediaFile!.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _isLoading ? null : _clearMedia,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isLoading ? null : () => _showMediaPickerSheet(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(14),
            ),
            child: _isUploadingMedia
                ? const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 18, color: Colors.black87),
                        SizedBox(width: 6),
                        Icon(Icons.videocam_outlined, size: 18, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Upload photo or video', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
          ),
        ),
        if (_mediaError != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(child: Text(_mediaError!, style: const TextStyle(fontSize: 11))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showMediaPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Choose a photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickMedia(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Choose a video'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickMedia(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Gradient? gradient;
  final BoxBorder? border;
  final Widget icon;
  final Color? iconBg;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  const _ChoiceButton({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    this.gradient,
    this.border,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? Colors.white : null,
            border: border,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg ?? Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: subtitleColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
