import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/core/constants/app_constants.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/data/models/auth_user.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  AnimationController? _coinController;
  AnimationController? _auroraController;
  AnimationController? _floatController;
  AnimationController? _fadeUpController;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String _error = '';
  String _nameError = '';
  String _emailError = '';
  String _mobileError = '';

  @override
  void initState() {
    super.initState();
    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _fadeUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
    _mobileController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _coinController?.dispose();
    _auroraController?.dispose();
    _floatController?.dispose();
    _fadeUpController?.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool valid = true;
    setState(() {
      _error = '';
      _nameError = '';
      _emailError = '';
      _mobileError = '';
    });
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required');
      valid = false;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!AppConstants.emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email');
      valid = false;
    }
    if (_mobileController.text.trim().isEmpty) {
      setState(() => _mobileError = 'Mobile number is required');
      valid = false;
    } else if (!AppConstants.mobileRegex.hasMatch(_mobileController.text.trim())) {
      setState(() => _mobileError = 'Please enter a valid 10-digit mobile number');
      valid = false;
    }
    return valid;
  }

  Future<void> _sendOtp() async {
    if (!_validateForm()) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await ref.read(authProvider.notifier).registerSendOtp(
        mobileNumber: _mobileController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (response.success) {
        setState(() {
          _otpSent = true;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (!AppConstants.otpRegex.hasMatch(_otpController.text.trim())) {
      setState(() => _error = 'Please enter a valid 4-6 digit OTP');
      return;
    }
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final response = await ref.read(authProvider.notifier).registerVerifyOtp(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
        otp: _otpController.text.trim(),
      );

      if (response.success && response.token != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome to Gift360!'),
              backgroundColor: AppColors.success,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) context.go('/');
        }
      } else {
        setState(() {
          _error = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9747FF), Color(0xFFFFFFFF)],
            stops: [-3.55, 0.9968],
          ),
        ),
        child: Stack(
          children: [
            // Layer 1: Floating Coins
            ...List.generate(10, (i) => _buildCoin(i)),

            // Layer 2: Aurora Blurs
            _buildAuroraBlur1(),
            _buildAuroraBlur2(),
            _buildAuroraBlur3(),

            // Layer 3: Grain Texture
            _buildGrainTexture(),

            // Layer 4: Content
            if (_fadeUpController != null)
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeUpController!,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: _fadeUpController!,
                      curve: Curves.easeOut,
                    )),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                      child: Column(
                        children: [
                          // Section A: Branding
                          _buildBranding(),

                          const SizedBox(height: 24),

                          // Section B: Purple Card
                          _buildPurpleCard(),

                          const SizedBox(height: 24),

                          // Section C: Footer
                          _buildFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LAYER 1: FLOATING COINS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildCoin(int index) {
    final random = Random(index);
    final size = 8.0 + random.nextDouble() * 10;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final delay = random.nextDouble() * 9;
    final isGold = index % 3 != 2;

    return AnimatedBuilder(
      animation: _coinController!,
      builder: (context, child) {
        final progress = (_coinController!.value + delay / 9) % 1.0;
        final yOffset = 40.0 + progress * -500;
        final xDrift = sin(progress * 2 * pi * 2) * 30;
        final rotation = progress * 2 * pi;

        return Positioned(
          left: left + xDrift,
          bottom: -40 + yOffset,
          child: Transform.rotate(
            angle: rotation,
            child: Opacity(
              opacity: (sin(progress * pi) * 0.5 + 0.5).clamp(0.0, 1.0),
              child: isGold
                  ? _buildGoldCoin(size)
                  : _buildStarSparkle(size * 0.72),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoldCoin(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [
            Color(0xFFFFEEA0),
            Color(0xFFD4A017),
            Color(0xFF8B6914),
          ],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x8CFFB433),
            blurRadius: 14,
          ),
          BoxShadow(
            color: const Color(0x59FFB433).withValues(alpha: 0.35),
            blurRadius: 4,
            spreadRadius: -1,
          ),
        ],
      ),
    );
  }

  Widget _buildStarSparkle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment(-1, -1),
          end: Alignment(1, 1),
          colors: [Colors.white, Color(0xFFE5C100)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xB3FFB433),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LAYER 2: AURORA BLURS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildAuroraBlur1() {
    return AnimatedBuilder(
      animation: _auroraController!,
      builder: (context, child) {
        final t = _auroraController!.value;
        final xOffset = sin(t * 2 * pi) * 20;
        final yOffset = cos(t * 2 * pi) * -10;
        final scale = 1.0 + sin(t * 2 * pi) * 0.1;
        final opacity = 0.6 + sin(t * 2 * pi) * 0.25;

        return Positioned(
          top: -40 + yOffset,
          left: -40 + xOffset,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 288,
                height: 288,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0x389747FF),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuroraBlur2() {
    return AnimatedBuilder(
      animation: _auroraController!,
      builder: (context, child) {
        final t = (_auroraController!.value + 0.25) % 1.0;
        final xOffset = sin(t * 2 * pi) * 20;
        final yOffset = cos(t * 2 * pi) * -10;
        final scale = 1.0 + sin(t * 2 * pi) * 0.1;
        final opacity = 0.6 + sin(t * 2 * pi) * 0.25;

        return Positioned(
          top: 128 + yOffset,
          right: -64 + xOffset,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0x2E73A3FF),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAuroraBlur3() {
    return AnimatedBuilder(
      animation: _auroraController!,
      builder: (context, child) {
        final t = (_auroraController!.value + 0.5) % 1.0;
        final xOffset = sin(t * 2 * pi) * 20;
        final yOffset = cos(t * 2 * pi) * -10;
        final scale = 1.0 + sin(t * 2 * pi) * 0.1;
        final opacity = 0.6 + sin(t * 2 * pi) * 0.25;

        return Positioned(
          bottom: 80 + yOffset,
          left: MediaQuery.of(context).size.width * 0.25 + xOffset,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 224,
                height: 224,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0x24F5C518),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LAYER 3: GRAIN TEXTURE
  // ════════════════════════════════════════════════════════════════════
  Widget _buildGrainTexture() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.30,
          child: CustomPaint(
            painter: _GrainPainter(),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SECTION A: BRANDING
  // ════════════════════════════════════════════════════════════════════
  Widget _buildBranding() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _floatController!,
          builder: (context, child) {
            final yOff = sin(_floatController!.value * pi) * 10;
            return Transform.translate(
              offset: Offset(0, -yOff),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(
                        begin: Alignment(-1, -1),
                        end: Alignment(1, 1),
                        colors: [
                          Color(0xFFE5C100),
                          Color(0xFFF57C00),
                          Color(0xFFE5A800),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xCCFFD700),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5343B2),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1FFFFFFF),
                          blurRadius: 0,
                          spreadRadius: 0,
                          offset: Offset(0, 1),
                        ),
                        BoxShadow(
                          color: Color(0x2ED7D7FF),
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Color(0xA6000000),
                          blurRadius: 40,
                          spreadRadius: -16,
                          offset: Offset(0, 18),
                        ),
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 12,
                          spreadRadius: -6,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        size: 32,
                        color: Color(0xFFFCD34D),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Create Account',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Join Gift360 today',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SECTION B: PREMIUM PURPLE CARD
  // ════════════════════════════════════════════════════════════════════
  Widget _buildPurpleCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF5343B2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FFFFFFF),
            blurRadius: 0,
            spreadRadius: 0,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x2ED7D7FF),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Color(0xA6000000),
            blurRadius: 40,
            spreadRadius: -16,
            offset: Offset(0, 18),
          ),
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 12,
            spreadRadius: -6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Hologram Sheen
          Positioned(
            top: -48,
            left: -48,
            child: AnimatedBuilder(
              animation: _auroraController!,
              builder: (context, child) {
                final t = (_auroraController!.value * 2) % 1.0;
                final xOffset = sin(t * 2 * pi) * 60;
                final opacity = 0.55 + sin(t * 2 * pi) * 0.3;

                return Transform.translate(
                  offset: Offset(xOffset, 0),
                  child: Transform.rotate(
                    angle: 20 * pi / 180,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 288,
                        height: 128,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Card Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Color(0xFFFCD34D),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sign Up',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error message
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Full Name Field
              _buildLabel('FULL NAME'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _nameController,
                hint: 'Enter your full name',
                icon: Icons.person_outline,
                enabled: !_otpSent,
              ),
              if (_nameError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _nameError,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Email Field
              _buildLabel('EMAIL'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _emailController,
                hint: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                icon: Icons.mail_outline,
                enabled: !_otpSent,
              ),
              if (_emailError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _emailError,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Mobile Number Field
              _buildLabel('MOBILE NUMBER'),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _mobileController,
                      hint: '10-digit number',
                      keyboardType: TextInputType.phone,
                      enabled: !_otpSent,
                      prefixWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 12),
                          Icon(
                            Icons.smartphone,
                            size: 20,
                            color: const Color(0xFFFCD34D).withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+91',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSendOtpButton(),
                ],
              ),
              if (_mobileError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _mobileError,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Success message
              if (_otpSent && _mobileError.isEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 12,
                      color: Color(0xFF6EE7B7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'OTP sent successfully',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6EE7B7),
                      ),
                    ),
                  ],
                ),
              ],

              // OTP Field
              if (_otpSent) ...[
                const SizedBox(height: 16),
                _buildLabel('ENTER OTP'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          autofillHints: const [],
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: 16,
                          ),
                          decoration: InputDecoration(
                            filled: false,
                            hintText: '• • • • • •',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontWeight: FontWeight.w400,
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildVerifyButton(),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SECTION C: FOOTER
  // ════════════════════════════════════════════════════════════════════
  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Text(
                'Sign in',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'By creating an account, you agree to our Terms and Privacy Policy',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ════════════════════════════════════════════════════════════════════
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.7),
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    IconData? icon,
    Widget? prefixWidget,
    bool enabled = true,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        autofillHints: const [],
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          filled: false,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.4),
            fontWeight: FontWeight.w400,
            fontSize: 14,
          ),
          counterText: '',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: prefixWidget ??
              (icon != null
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(
                        icon,
                        size: 16,
                        color: const Color(0xFFFCD34D).withValues(alpha: 0.8),
                      ),
                    )
                  : null),
        ),
      ),
    );
  }

  Widget _buildSendOtpButton() {
    final isValid = AppConstants.mobileRegex.hasMatch(_mobileController.text) &&
        AppConstants.emailRegex.hasMatch(_emailController.text) &&
        _nameController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: (_isLoading || _otpSent || !isValid) ? null : _sendOtp,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: _otpSent
              ? null
              : LinearGradient(
                  colors: [AppColors.gold, AppColors.goldLight],
                ),
          color: _otpSent ? AppColors.success.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(16),
          border: _otpSent
              ? Border.all(color: AppColors.success.withValues(alpha: 0.4))
              : null,
          boxShadow: _otpSent
              ? null
              : [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            _isLoading ? 'Sending...' : _otpSent ? '✓ Sent' : 'Send OTP',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _otpSent
                  ? AppColors.success
                  : const Color(0xFF1A0D00),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final isValid = AppConstants.otpRegex.hasMatch(_otpController.text);
    return GestureDetector(
      onTap: (_isLoading || !isValid) ? null : _verifyOtp,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gold, AppColors.goldLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isLoading ? 'Verifying...' : 'Verify',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A0D00),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Color(0xFF1A0D00),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// GRAIN TEXTURE PAINTER
// ════════════════════════════════════════════════════════════════════
class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += 3) {
      for (double y = 0; y < size.height; y += 3) {
        if (random.nextBool()) {
          paint.color = Colors.white.withValues(alpha: 0.06);
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        }
      }
    }

    for (double x = 2; x < size.width; x += 5) {
      for (double y = 2; y < size.height; y += 5) {
        if (random.nextBool()) {
          paint.color = Colors.white.withValues(alpha: 0.04);
          canvas.drawCircle(Offset(x, y), 0.5, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
