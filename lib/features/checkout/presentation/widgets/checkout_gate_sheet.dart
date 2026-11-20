import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/core/utils/checkout_device_id.dart';
import 'package:gift360/features/checkout/data/checkout_gate.dart';
import 'package:gift360/features/checkout/data/checkout_gate_logic.dart';
import 'package:gift360/features/checkout/data/models/checkout_models.dart';
import 'package:gift360/features/checkout/data/repositories/checkout_api.dart';

const _purple = Color(0xFF7C3AED);
const _purpleDark = Color(0xFF5537BE);
const _pinPattern = r'^[1-9][0-9]{5}$';

/// Dismissing the sheet (back, barrier tap, drag) cancels the payment.
CheckoutGateResult checkoutGateResultFromSheet(CheckoutGateResult? result) =>
    result ?? const CheckoutGateResult.cancelled();

Future<CheckoutGateResult> presentCheckoutGate({
  required CheckoutApi api,
  required CheckoutRequirements requirements,
  required bool needEmail,
  required bool needLocation,
}) async {
  final context = appRootContext;
  if (context == null) return const CheckoutGateResult.notShown();

  final result = await showModalBottomSheet<CheckoutGateResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CheckoutGateSheet(
      api: api,
      requirements: requirements,
      needEmail: needEmail,
      needLocation: needLocation,
    ),
  );
  return checkoutGateResultFromSheet(result);
}

enum _CheckoutStep { email, location }

enum _LocationStepMode { choose, confirm, pin }

class CheckoutGateSheet extends StatefulWidget {
  final CheckoutApi api;
  final CheckoutRequirements requirements;
  final bool needEmail;
  final bool needLocation;

  const CheckoutGateSheet({
    super.key,
    required this.api,
    required this.requirements,
    required this.needEmail,
    required this.needLocation,
  });

  @override
  State<CheckoutGateSheet> createState() => _CheckoutGateSheetState();
}

class _CheckoutGateSheetState extends State<CheckoutGateSheet> {
  late _CheckoutStep _step;
  late bool _emailDone;
  final _codeController = TextEditingController();
  final _pinController = TextEditingController();
  bool _busy = false;
  bool _codeSent = false;
  bool _consent = false;
  String? _emailMessage;
  String? _locationMessage;
  String? _gpsLabel;
  CheckoutLocation? _gps;
  _LocationStepMode _locationMode = _LocationStepMode.choose;
  DateTime? _resendAt;
  DateTime _now = DateTime.now();
  Timer? _resendTimer;
  bool _settled = false;

  CheckoutEmailRequirement? get _email => widget.requirements.email;
  CheckoutLocationRequirement? get _location => widget.requirements.location;
  bool get _canResend =>
      _codeSent && (_resendAt == null || !_now.isBefore(_resendAt!));

  @override
  void initState() {
    super.initState();
    _step = widget.needEmail ? _CheckoutStep.email : _CheckoutStep.location;
    _emailDone = !widget.needEmail;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.clear();
    _codeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _complete({CheckoutLocation? location}) {
    if (_settled) return;
    _settled = true;
    _codeController.clear();
    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(CheckoutGateResult.completed(location: location));
  }

  void _cancel() {
    if (_settled) return;
    _settled = true;
    _codeController.clear();
    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(const CheckoutGateResult.cancelled());
  }

  void _afterEmail() {
    _emailDone = true;
    if (widget.needLocation) {
      setState(() => _step = _CheckoutStep.location);
    } else {
      _complete();
    }
  }

  void _closeStep() {
    // Verification is mandatory: any dismissal cancels the payment start.
    _cancel();
  }

  Future<void> _sendCode() async {
    if (_busy || _email?.invalidReason != null) return;
    setState(() {
      _busy = true;
      _emailMessage = null;
    });
    try {
      final result = await widget.api.sendEmailCode(
        deviceId: await getCheckoutDeviceId(),
      );
      final status = (result['status'] ?? '').toString();
      if (status == 'ALREADY_VERIFIED' || status == 'DISABLED') {
        _afterEmail();
        return;
      }
      if (status == 'SENT') {
        _codeSent = true;
        _resendAt = DateTime.now().add(const Duration(seconds: 30));
        _resendTimer?.cancel();
        _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _now = DateTime.now());
          if (_canResend) {
            _resendTimer?.cancel();
            _resendTimer = null;
          }
        });
      }
      final retry = (result['retryAfterSeconds'] as num?)?.toInt();
      setState(
        () => _emailMessage = emailSendStatusMessage(
          status,
          retryAfterSeconds: retry,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _emailMessage =
              "We couldn't send the code just now. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCode() async {
    final code = _codeController.text;
    if (_busy || code.length != 6) return;
    setState(() {
      _busy = true;
      _emailMessage = null;
    });
    try {
      final result = await widget.api.confirmEmailCode(code: code);
      final status = (result['status'] ?? '').toString();
      if (status == 'VERIFIED' ||
          status == 'ALREADY_VERIFIED' ||
          status == 'DISABLED') {
        _codeController.clear();
        _afterEmail();
        return;
      }
      final attempts = (result['attemptsLeft'] as num?)?.toInt();
      final retry = (result['retryAfterSeconds'] as num?)?.toInt();
      setState(() {
        _emailMessage = emailConfirmStatusMessage(
          status,
          attemptsLeft: attempts,
          retryAfterSeconds: retry,
        );
        _codeController.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _emailMessage = 'Something went wrong. Please try again.';
          _codeController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useMyLocation() async {
    if (_busy || !_consent) return;
    setState(() {
      _busy = true;
      _locationMessage = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationFailed(denied: false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationFailed(denied: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final place = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      final postcode = _validPin(place?.postcode) ? place!.postcode : null;
      final city = _nonEmpty(place?.city);
      final state = _nonEmpty(place?.state);
      final timestamp = position.timestamp.millisecondsSinceEpoch;
      final gps = CheckoutLocation.gps(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: timestamp,
        pincode: postcode,
        city: city,
        state: state,
      );
      final label = [city, state].whereType<String>().join(', ');
      final pinLabel = postcode == null ? '' : ' · PIN $postcode';
      if (!mounted) return;
      setState(() {
        _gps = gps;
        _gpsLabel = label.isEmpty ? 'Location found' : '$label$pinLabel';
        _locationMode = _LocationStepMode.confirm;
      });
    } on LocationServiceDisabledException {
      _locationFailed(denied: false);
    } on PermissionDeniedException {
      _locationFailed(denied: true);
    } catch (_) {
      _locationFailed(denied: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _locationFailed({required bool denied}) {
    if (!mounted) return;
    setState(() {
      _locationMessage = denied
          ? 'Location permission is off. You can enter your PIN code instead.'
          : "We couldn't get your location. You can enter your PIN code instead.";
      if (_location?.pinFallback == true) {
        _locationMode = _LocationStepMode.pin;
      }
    });
  }

  void _confirmGps() {
    final gps = _gps;
    if (gps == null || !_consent) return;
    _complete(
      location: CheckoutLocation.gps(
        latitude: gps.latitude!,
        longitude: gps.longitude!,
        accuracyMeters: gps.accuracyMeters!,
        capturedAt: DateTime.now().millisecondsSinceEpoch,
        pincode: gps.pincode,
        city: gps.city,
        state: gps.state,
      ),
    );
  }

  void _confirmPin() {
    final pin = _pinController.text.replaceAll(RegExp(r'\s'), '');
    if (!_consent) return;
    if (!_validPin(pin)) {
      setState(
        () => _locationMessage = 'Please enter a valid 6-digit PIN code.',
      );
      return;
    }
    _complete(
      location: CheckoutLocation.pin(
        pincode: pin,
        capturedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<_ReversePlace?> _reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await Dio().get<Map<String, dynamic>>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'format': 'json',
          'lat': latitude,
          'lon': longitude,
          'zoom': 18,
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'Gift360App/1.0'}),
      );
      final data = response.data;
      if (data == null || data['error'] != null) return null;
      final rawAddress = data['address'];
      if (rawAddress is! Map) return null;
      final address = rawAddress.cast<String, dynamic>();
      final city = _firstNonEmpty([
        address['city'],
        address['town'],
        address['village'],
        address['county'],
        address['state_district'],
      ]);
      final postcode = _nonEmpty(
        address['postcode'],
      )?.replaceAll(RegExp(r'\s'), '');
      return _ReversePlace(
        city: city,
        state: _nonEmpty(address['state']),
        postcode: postcode,
      );
    } catch (_) {
      return null;
    }
  }

  bool _validPin(String? pin) =>
      pin != null && RegExp(_pinPattern).hasMatch(pin);

  String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final result = _nonEmpty(value);
      if (result != null) return result;
    }
    return null;
  }

  Widget _actionButton({
    required String label,
    required VoidCallback? onPressed,
    bool secondary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: secondary
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(color: Color(0xFFD8C7FF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB9A2EB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  Widget _message(String? text) {
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          color: const Color(0xFFB42318),
        ),
      ),
    );
  }

  Widget _emailBody() {
    final email = _email;
    if (email == null) return const SizedBox.shrink();
    final invalid = email.invalidReason != null;
    final remaining = _resendAt == null
        ? 0
        : _resendAt!.difference(_now).inSeconds.clamp(0, 30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm your email',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'This is being asked to send vouchers for your registered email ID for security purposes.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 18),
        if (invalid) ...[
          _message(invalidEmailMessage(email.invalidReason)),
          if (email.maskedEmail != null) ...[
            const SizedBox(height: 10),
            Text(
              'Current email: ${email.maskedEmail}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
          if (email.suggestion != null) ...[
            const SizedBox(height: 6),
            Text(
              'Did you mean ${email.suggestion}?',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Please update it in your Profile, then come back to pay.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          _actionButton(label: 'Go to Profile', onPressed: _goToProfile),
        ] else if (!_codeSent) ...[
          Text(
            "We'll send a 6-digit code to ${email.maskedEmail ?? 'your email'}.",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          _actionButton(
            label: _busy ? 'Sending…' : 'Send code',
            onPressed: _busy ? null : _sendCode,
          ),
        ] else ...[
          Text(
            'Enter the code sent to ${email.maskedEmail ?? 'your email'}. It expires in 10 minutes.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              color: const Color(0xFF1F2937),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 2),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _actionButton(
            label: _busy ? 'Checking…' : 'Verify',
            onPressed: _busy || _codeController.text.length != 6
                ? null
                : _confirmCode,
          ),
          const SizedBox(height: 8),
          _actionButton(
            label: _canResend
                ? 'Send a new code'
                : 'Send a new code in ${remaining}s',
            onPressed: _busy || !_canResend ? null : _sendCode,
            secondary: true,
          ),
        ],
        if (_emailMessage != null) ...[
          const SizedBox(height: 10),
          _message(_emailMessage),
        ],
      ],
    );
  }

  Widget _locationBody() {
    final location = _location;
    if (location == null || !_emailDone) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Confirm your location',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          location.notice,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _consent,
          onChanged: (value) => setState(() {
            _consent = value == true;
            _locationMessage = null;
          }),
          title: Text(
            'I agree to share my location for this payment.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF374151),
            ),
          ),
          activeColor: _purple,
        ),
        if (_locationMode == _LocationStepMode.confirm && _gps != null) ...[
          const SizedBox(height: 8),
          Text(
            'You are in ${_gpsLabel ?? 'Location found'}. Is this right?',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF374151),
            ),
          ),
        ],
        if (_locationMode == _LocationStepMode.pin) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              hintText: '6-digit PIN code',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _purple, width: 2),
              ),
            ),
            onChanged: (_) => setState(() => _locationMessage = null),
          ),
        ],
        if (_locationMessage != null) ...[
          const SizedBox(height: 8),
          _message(_locationMessage),
        ],
        const SizedBox(height: 12),
        if (_locationMode == _LocationStepMode.choose)
          _actionButton(
            label: _busy ? 'Finding you…' : 'Use my location',
            onPressed: _busy || !_consent ? null : _useMyLocation,
          ),
        if (_locationMode == _LocationStepMode.confirm)
          _actionButton(
            label: 'Yes, continue to pay',
            onPressed: _consent ? _confirmGps : null,
          ),
        if (_locationMode == _LocationStepMode.pin)
          _actionButton(
            label: 'Continue with this PIN code',
            onPressed: !_consent || _pinController.text.length != 6
                ? null
                : _confirmPin,
          ),
        if (location.pinFallback &&
            _locationMode == _LocationStepMode.choose) ...[
          const SizedBox(height: 8),
          _actionButton(
            label: 'Enter PIN code instead',
            onPressed: _busy
                ? null
                : () => setState(() {
                    _locationMode = _LocationStepMode.pin;
                    _locationMessage = null;
                  }),
            secondary: true,
          ),
        ],
      ],
    );
  }

  void _goToProfile() {
    _cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = appRootContext;
      if (context != null) GoRouter.of(context).go('/profile');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = _step == _CheckoutStep.email;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeStep();
      },
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              maxWidth: 520,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_purple, _purpleDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEmail ? 'Secure checkout' : 'Payment location',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _busy ? null : _closeStep,
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: isEmail ? _emailBody() : _locationBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReversePlace {
  final String? city;
  final String? state;
  final String? postcode;

  const _ReversePlace({this.city, this.state, this.postcode});
}
