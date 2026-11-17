import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:gift360/core/constants/app_colors.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/profile/data/profile_details_store.dart';

/// Edit / complete profile: Name, Email, Mobile (from login), Gender, DOB.
class ProfileDetailsScreen extends ConsumerStatefulWidget {
  /// When true, this is the post-login setup for a new / incomplete profile.
  final bool isSetup;

  const ProfileDetailsScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  String _gender = '';
  DateTime? _dob;
  bool _loading = true;
  bool _saving = false;

  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final user = ref.read(authProvider);
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final details = await ProfileDetailsStore.load(user);
    if (!mounted) return;
    _nameController.text = details.name;
    _emailController.text = details.email;
    _gender = details.gender;
    _dob = DateTime.tryParse(details.dateOfBirth);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryPurple,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _saving = true);
    final details = ProfileDetails(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      gender: _gender,
      dateOfBirth: DateFormat('yyyy-MM-dd').format(_dob!),
    );

    await ProfileDetailsStore.save(user, details);
    ref.read(authProvider.notifier).setUser(
          user.copyWith(name: details.name, email: details.email),
        );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );

    if (widget.isSetup) {
      context.go('/');
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FB),
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('Sign in to continue'),
          ),
        ),
      );
    }

    final mobile = user.mobile.trim().isEmpty ? '—' : user.mobile.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: widget.isSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
        automaticallyImplyLeading: !widget.isSetup,
        title: Text(
          widget.isSetup ? 'Complete your profile' : 'Profile details',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1F1635),
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFECE8F4)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    if (widget.isSetup) ...[
                      Text(
                        'Tell us a bit about you',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F1635),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your mobile number is already verified from login.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF81789A),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _fieldCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('Full name'),
                          TextFormField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration('Enter your name'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Name is required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          _label('Email'),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('Enter your email'),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Email is required';
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _label('Mobile number'),
                          TextFormField(
                            initialValue: mobile,
                            enabled: false,
                            decoration: _inputDecoration('Verified mobile')
                                .copyWith(
                              filled: true,
                              fillColor: const Color(0xFFF3F0F8),
                              suffixIcon: const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF16A34A),
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Verified at login — cannot be changed here',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF81789A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _label('Gender'),
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _gender.isEmpty ? null : _gender,
                            decoration: _inputDecoration('Select gender'),
                            items: _genders
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _gender = v ?? ''),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Gender is required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          _label('Date of birth'),
                          InkWell(
                            onTap: _pickDob,
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: _inputDecoration('Select date of birth')
                                  .copyWith(
                                suffixIcon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                              child: Text(
                                _dob == null
                                    ? 'Select date of birth'
                                    : DateFormat('dd MMM yyyy').format(_dob!),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _dob == null
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF1F1635),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD1D5DB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isSetup ? 'Save & continue' : 'Save details',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E3F2)),
      ),
      child: child,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF6B6280),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF9CA3AF)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E0F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E0F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E0F0)),
      ),
    );
  }
}
