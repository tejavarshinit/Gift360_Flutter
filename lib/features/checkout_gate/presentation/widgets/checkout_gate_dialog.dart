import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/features/checkout_gate/data/models/checkout_models.dart';
import 'package:gift360/features/checkout_gate/data/repositories/checkout_api.dart';

enum _GateStep { email, location }

/// Email OTP + location (GPS / postal PIN) dialog for checkout.
class CheckoutGateDialog extends StatefulWidget {
  final CheckoutApi api;
  final CheckoutRequirements requirements;
  final String? profileEmail;

  const CheckoutGateDialog({
    super.key,
    required this.api,
    required this.requirements,
    this.profileEmail,
  });

  static Future<CheckoutGateResult> show(
    BuildContext context, {
    required CheckoutApi api,
    required CheckoutRequirements requirements,
    String? profileEmail,
  }) async {
    final result = await showDialog<CheckoutGateResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckoutGateDialog(
        api: api,
        requirements: requirements,
        profileEmail: profileEmail,
      ),
    );
    return result ?? CheckoutGateResult.cancelled();
  }

  @override
  State<CheckoutGateDialog> createState() => _CheckoutGateDialogState();
}

class _CheckoutGateDialogState extends State<CheckoutGateDialog> {
  late _GateStep _step;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _pinCtrl;

  bool _codeSent = false;
  bool _loading = false;
  bool _consent = false;
  String _error = '';
  String? _suggestion;
  bool _suggestionUsed = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  CheckoutLocation? _gpsLocation;
  String? _gpsLabel;

  CheckoutEmailRequirement get _email => widget.requirements.email;
  CheckoutLocationRequirement get _location => widget.requirements.location;

  bool get _canSkipEmail => !_email.required;
  bool get _canSkipLocation => !_location.required;

  @override
  void initState() {
    super.initState();
    _step = _email.shouldAsk ? _GateStep.email : _GateStep.location;
    _emailCtrl = TextEditingController(
      text: widget.profileEmail?.trim() ?? '',
    );
    _codeCtrl = TextEditingController();
    _pinCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    setState(() {
      _error = '';
      _suggestion = null;
    });
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() => _loading = true);
    try {
      final check = await widget.api.checkEmail(email);
      if (check.suggestion != null &&
          check.suggestion!.isNotEmpty &&
          !_suggestionUsed) {
        setState(() {
          _suggestion = check.suggestion;
          _loading = false;
        });
        return;
      }
      if (check.block) {
        setState(() {
          _error = check.message ??
              check.invalidReason ??
              'This email cannot be used. Update it in Profile.';
          _loading = false;
        });
        return;
      }

      await widget.api.sendEmailVerificationCode(email: email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _loading = false;
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await widget.api.confirmEmailVerificationCode(code);
      if (!mounted) return;
      if (_location.ask) {
        setState(() {
          _step = _GateStep.location;
          _loading = false;
          _error = '';
        });
      } else {
        Navigator.of(context).pop(CheckoutGateResult.proceeded());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendly(e);
        _loading = false;
      });
    }
  }

  void _skipEmail() {
    if (!_canSkipEmail) return;
    if (_location.ask) {
      setState(() {
        _step = _GateStep.location;
        _error = '';
      });
    } else {
      Navigator.of(context).pop(CheckoutGateResult.proceeded());
    }
  }

  Future<void> _useGps() async {
    if (!_consent) {
      setState(() => _error = 'Please tick consent to share location');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _error = 'Location is turned off. Enter PIN code instead.';
          _loading = false;
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Permission denied. Enter PIN code instead.';
          _loading = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final loc = CheckoutLocation(
        source: 'GPS',
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracyMeters: pos.accuracy,
        capturedAt: DateTime.now().millisecondsSinceEpoch,
        consent: true,
      );
      setState(() {
        _gpsLocation = loc;
        _gpsLabel =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'
            ' (±${pos.accuracy.toStringAsFixed(0)}m)';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not get GPS. Enter PIN code instead.';
        _loading = false;
      });
    }
  }

  void _confirmGps() {
    final loc = _gpsLocation;
    if (loc == null) return;
    Navigator.of(context).pop(CheckoutGateResult.proceeded(loc));
  }

  void _confirmPin() {
    if (!_consent) {
      setState(() => _error = 'Please tick consent to share location');
      return;
    }
    final pin = _pinCtrl.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a valid 6-digit postal PIN');
      return;
    }
    final loc = CheckoutLocation(
      source: 'PIN',
      pincode: pin,
      capturedAt: DateTime.now().millisecondsSinceEpoch,
      consent: true,
    );
    Navigator.of(context).pop(CheckoutGateResult.proceeded(loc));
  }

  void _skipLocation() {
    if (!_canSkipLocation) return;
    Navigator.of(context).pop(CheckoutGateResult.proceeded());
  }

  void _close() {
    // HARD/ENFORCE: closing cancels payment.
    Navigator.of(context).pop(CheckoutGateResult.cancelled());
  }

  String _friendly(Object e) {
    final msg = e.toString();
    if (msg.length > 140) return 'Something went wrong. Please try again.';
    return msg.replaceFirst('Exception: ', '').replaceFirst('DioException: ', '');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _step == _GateStep.email
                            ? 'Verify your email'
                            : 'Confirm your location',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF3F1A55),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_step == _GateStep.email) _buildEmailStep() else _buildLocationStep(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _email.maskedEmail != null && _email.maskedEmail!.isNotEmpty
              ? 'We\'ll send a 6-digit code to ${_email.maskedEmail}'
              : 'Confirm the email we\'ll use for this purchase',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          enabled: !_codeSent,
          decoration: _decoration('Email address'),
        ),
        if (_suggestion != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _emailCtrl.text = _suggestion!;
                _suggestionUsed = true;
                _suggestion = null;
              });
            },
            child: Text(
              'Did you mean $_suggestion? Tap to use it',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ),
        ],
        if (_codeSent) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _decoration('6-digit code').copyWith(counterText: ''),
          ),
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _error,
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFDC2626)),
          ),
          if (_error.toLowerCase().contains('profile')) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(CheckoutGateResult.cancelled());
                context.push('/profile/details');
              },
              child: const Text('Go to Profile'),
            ),
          ],
        ],
        const SizedBox(height: 14),
        _primaryButton(
          label: _loading
              ? 'Please wait…'
              : _codeSent
                  ? 'Verify'
                  : 'Send code',
          onTap: _loading
              ? null
              : _codeSent
                  ? _verifyCode
                  : _sendCode,
        ),
        if (_codeSent) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_loading || _resendSeconds > 0) ? null : _sendCode,
            child: Text(
              _resendSeconds > 0
                  ? 'Resend in ${_resendSeconds}s'
                  : 'Resend code',
            ),
          ),
        ],
        if (_canSkipEmail) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : _skipEmail,
            child: Text(
              'Skip for now',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_location.notice != null && _location.notice!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _location.notice!,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
          ),
        CheckboxListTile(
          value: _consent,
          onChanged: (v) => setState(() => _consent = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'I agree to share my location for this purchase',
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ),
        if (_gpsLocation != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEF8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _gpsLabel ?? 'Location captured',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          _primaryButton(
            label: 'Yes, continue to pay',
            onTap: _loading ? null : _confirmGps,
          ),
        ] else ...[
          _primaryButton(
            label: _loading ? 'Getting location…' : 'Use my location',
            onTap: _loading ? null : _useGps,
          ),
          if (_location.pinFallback) ...[
            const SizedBox(height: 12),
            Text(
              'Or enter postal PIN',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration('6-digit PIN code').copyWith(counterText: ''),
            ),
            const SizedBox(height: 8),
            _primaryButton(
              label: 'Continue with PIN',
              onTap: _loading ? null : _confirmPin,
            ),
          ],
        ],
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _error,
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFDC2626)),
          ),
        ],
        if (_canSkipLocation) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _loading ? null : _skipLocation,
            child: Text(
              'Skip',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B7280)),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF7B3DC3)),
      ),
    );
  }

  Widget _primaryButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7B3DC3), Color(0xFF5537BE)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
