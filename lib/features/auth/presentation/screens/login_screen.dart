import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/constants/app_constants.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isSessionExpired;
  const LoginScreen({super.key, this.isSessionExpired = false});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _mobileController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _otpSent = false;
  bool _isLoading = false;
  String _otpMessage = '';
  String _error = '';
  String _mobileError = '';

  // Brand logos for marquee (matching React)
  static const _brandLogos = [
    'assets/images/amazon.png',
    'assets/images/flipkart.png',
    'assets/images/myntra.png',
    'assets/images/nike.png',
    'assets/images/puma.png',
    'assets/images/bata.png',
    'assets/images/levis.png',
    'assets/images/tatacliq.png',
    'assets/images/ajio.png',
    'assets/images/zomato.png',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isSessionExpired) {
      _error = 'Your session has expired. Please login again.';
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  bool _validateMobile(String m) => AppConstants.mobileRegex.hasMatch(m);
  bool _validateOtp() =>
      _otpControllers.every((c) => c.text.length == 1);

  String get _otpString => _otpControllers.map((c) => c.text).join();

  void _clearErrors() {
    setState(() {
      _error = '';
      _mobileError = '';
    });
  }

  void _handleOtpInput(int index, String value) {
    if (!RegExp(r'^[0-9]?$').hasMatch(value)) return;
    setState(() {});
    if (value.isNotEmpty && index < 3) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleSendOtp() async {
    final mobile = _mobileController.text.trim();
    _clearErrors();
    setState(() {
      _otpMessage = '';
      _otpSent = false;
      for (final c in _otpControllers) {
        c.clear();
      }
    });

    if (mobile.isEmpty) {
      setState(() => _mobileError = 'Mobile number is required');
      return;
    }
    if (!_validateMobile(mobile)) {
      setState(
          () => _mobileError = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ref.read(authProvider.notifier).sendOtp(
            SendOtpRequest(mobileNumber: mobile),
          );
      if (response.notRegistered == true) {
        setState(() {
          _error = 'Mobile number not registered. Please register first.';
          _isLoading = false;
        });
        return;
      }
      if (response.success) {
        setState(() {
          _otpSent = true;
          _otpMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleOtpLogin() async {
    final mobile = _mobileController.text.trim();
    final otp = _otpString;
    _clearErrors();

    if (!_validateMobile(mobile)) {
      setState(() => _error = 'Please enter a valid mobile number');
      return;
    }
    if (!_validateOtp()) {
      setState(() => _error = 'Please enter a valid 4-digit OTP');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ref.read(authProvider.notifier).loginWithOtp(
            LoginWithOtpRequest(
              mobileNumber: mobile,
              otp: otp,
            ),
          );
      if (response.success && response.token != null) {
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) context.go('/');
        }
      } else {
        setState(() {
          _error =
              response.message.isNotEmpty ? response.message : 'OTP login failed';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _isLoading = false;
      });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('connection error') ||
        msg.contains('No internet') ||
        msg.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('connection timeout') ||
        msg.contains('receive timeout')) {
      return 'Connection timed out. Please try again.';
    }
    if (msg.contains('404')) return 'Service not found. Please try again later.';
    if (msg.contains('500')) return 'Server error. Please try again later.';
    if (msg.contains('401') || msg.contains('403')) {
      return 'Session expired. Please try again.';
    }
    if (msg.length > 120) return 'Something went wrong. Please try again.';
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── 1. Background image (matching React DiwaliAuthShell's diwali-bg) ──
            Positioned.fill(
              child: Image.asset(
                'assets/images/diwali-bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),

            // ── 2. Content ──
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Logo
                  Center(
                    child: Image.asset(
                      'assets/images/gift360full.png',
                      width: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Heading
                  Center(
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              height: 1.3,
                            ),
                            children: const [
                              TextSpan(text: 'India #1 Destination for '),
                              TextSpan(
                                text: 'Gifting',
                                style: TextStyle(color: Color(0xFF7C3AED)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Access 400+ brands Vouchers. Delivered instantly, and gift feeling',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Spacer pushes card to bottom ──
                  const Spacer(),

                  // ── White card ──
                  Center(
                    child: Container(
                      width: 342,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC9C9C9)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 4,
                            offset: Offset(4, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Started',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enter your mobile number to continue',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: const Color(0xFF4E4E4E),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Session expired alert
                          if (widget.isSessionExpired && _error.isNotEmpty)
                            _buildAlert(
                              _error,
                              isAmber: true,
                            ),

                          // Error alert
                          if (_error.isNotEmpty && !widget.isSessionExpired)
                            _buildAlert(_error),

                          // ── Mobile input ──
                          _buildMobileInput(),
                          if (_mobileError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _mobileError,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: Colors.red[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // ── Send OTP / OTP section ──
                          if (!_otpSent)
                            _buildSendOtpButton()
                          else
                            _buildOtpSection(),

                          // OTP success message
                          if (_otpMessage.isNotEmpty && _otpSent)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '✓ $_otpMessage',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  color: const Color(0xFF16a34a),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                          const SizedBox(height: 10),
                          // Secure note
                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_user_outlined,
                                  size: 12,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "we'll send a secure OTP to verify your number",
                                  style: GoogleFonts.poppins(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF4E4E4E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Sign up link ──
                  GestureDetector(
                    onTap: () => context.push('/register'),
                    child: Center(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E1E1E),
                          ),
                          children: [
                            const TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign up',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7C3AED),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── TRUSTED BY 400+ BRANDS ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFC9C9C9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TRUSTED BY 400+ BRANDS',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF35009A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFC9C9C9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Brand logos marquee ──
                  SizedBox(
                    height: 28,
                    child: _buildBrandMarquee(),
                  ),
                  const SizedBox(height: 8),

                  // ── Terms ──
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text.rich(
                        TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 7,
                            color: const Color(0xFF4E4E4E),
                          ),
                          children: [
                            const TextSpan(
                                text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: GoogleFonts.poppins(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: GoogleFonts.poppins(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile Input ──
  Widget _buildMobileInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD9D9D9)),
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Country code prefix
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F7FA),
                  border: Border(
                    right: BorderSide(color: Color(0xFFEBEBEB)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🇮🇳',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+91',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 10,
                      color: Color(0xFFA1A1A1),
                    ),
                  ],
                ),
              ),
              // Mobile number input
              Expanded(
                child: TextField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  enabled: !_otpSent,
                  onChanged: (_) => _clearErrors(),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter mobile number',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFFA6A4A4),
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Send OTP Button ──
  Widget _buildSendOtpButton() {
    final isValid = _validateMobile(_mobileController.text);
    return GestureDetector(
      onTap: (_isLoading || !isValid) ? null : _handleSendOtp,
      child: Opacity(
        opacity: (!isValid || _isLoading) ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7B3DC3), Color(0xFF5537BE)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40B78AF3),
                blurRadius: 8,
                offset: Offset(2, 4),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLoading ? 'Sending...' : 'Send OTP',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (!_isLoading) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.send_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── OTP Section ──
  Widget _buildOtpSection() {
    return Column(
      children: [
        // 4-digit OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            return Container(
              width: 52,
              height: 52,
              margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC9C9C9)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFF7C3AED), width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC9C9C9)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) => _handleOtpInput(i, v),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // Verify button
        GestureDetector(
          onTap: (_isLoading || !_validateOtp()) ? null : _handleOtpLogin,
          child: Opacity(
            opacity: (!_validateOtp() || _isLoading) ? 0.5 : 1.0,
            child: Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7B3DC3), Color(0xFF5537BE)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40B78AF3),
                    blurRadius: 8,
                    offset: Offset(2, 4),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLoading ? 'Verifying...' : 'Verify',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (!_isLoading) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Resend OTP
        Center(
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: const Color(0xFF4E4E4E),
              ),
              children: [
                const TextSpan(text: "Didn't Receive? "),
                WidgetSpan(
                  child: GestureDetector(
                    onTap: _handleSendOtp,
                    child: Text(
                      'Resend OTP',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF7C3AED),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Alert Widget ──
  Widget _buildAlert(String message, {bool isAmber = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAmber ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAmber
              ? const Color(0xFFFDE68A).withValues(alpha: 0.3)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAmber ? Icons.warning_amber_rounded : Icons.error_outline,
            size: 14,
            color: isAmber ? const Color(0xFFF59E0B) : Colors.red[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isAmber ? const Color(0xFF92400E) : Colors.red[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Brand Marquee ──
  Widget _buildBrandMarquee() {
    final allLogos = [..._brandLogos, ..._brandLogos];
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: allLogos.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Image.asset(
            allLogos[index],
            height: 22,
            fit: BoxFit.contain,
            opacity: const AlwaysStoppedAnimation(0.70),
          ),
        );
      },
    );
  }
}
