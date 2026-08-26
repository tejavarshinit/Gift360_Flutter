import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/contact/data/repositories/contact_api.dart';

class DistributorScreen extends StatefulWidget {
  const DistributorScreen({super.key});

  @override
  State<DistributorScreen> createState() => _DistributorScreenState();
}

class _DistributorScreenState extends State<DistributorScreen> {
  bool _showContactModal = false;
  bool _showMenu = false;
  bool _submitted = false;
  bool _loading = false;
  String? _error;

  final _orgNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _panController = TextEditingController();
  final _gstController = TextEditingController();
  final _messageController = TextEditingController();

  late final ContactApi _contactApi;

  @override
  void initState() {
    super.initState();
    _contactApi = ContactApi(Dio(BaseOptions(baseUrl: AppConfig.brandApiUrl)));
  }

  @override
  void dispose() {
    _orgNameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _panController.dispose();
    _gstController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _contactApi.submitLead(ContactLeadRequest(
        role: 'DISTRIBUTOR',
        organizationName: _orgNameController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pan: _panController.text.trim().toUpperCase(),
        gst: _gstController.text.trim().toUpperCase(),
        message: _messageController.text.trim(),
      ));
      setState(() {
        _submitted = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _closeModal() {
    setState(() {
      _showContactModal = false;
      _submitted = false;
      _loading = false;
      _error = null;
      _orgNameController.clear();
      _cityController.clear();
      _stateController.clear();
      _panController.clear();
      _gstController.clear();
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Stack(
        children: [
          Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeroSection(),
                      _buildFeaturesSection(),
                      _buildHowItWorksSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showMenu) _buildDropdownMenu(),
          if (_showContactModal) _buildContactModal(),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 12),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showMenu = !_showMenu),
            child: Text('⋮', style: GoogleFonts.poppins(fontSize: 18, color: const Color(0xFF374151))),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 52,
      right: 16,
      child: GestureDetector(
        onTap: () => setState(() => _showMenu = false),
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem('Distributor', '/distributor'),
              _buildMenuItem('Reseller', '/reseller'),
              _buildMenuItem('Corporate', '/corporate'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String label, String route) {
    return InkWell(
      onTap: () {
        setState(() => _showMenu = false);
        context.push(route);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0x339747FF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.work_outline, size: 12, color: Color(0xFF374151)),
                const SizedBox(width: 4),
                Text('Distributor Mode', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF374151))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF9747FF), Color(0xFF3B82F6)],
                      ).createShader(bounds),
                      child: Text(
                        'Become a Sabbpe Preferred Partner',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.21,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Buy a Gift Voucher in bulk with better pricing and faster processing',
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600], height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Image.asset(
                'assets/images/Dis.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, size: 60, color: Color(0xFF9747FF)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => setState(() => _showContactModal = true),
              child: Container(
                width: 180,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9747FF), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: const Color(0xFF9747FF).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Center(
                  child: Text('Get Started', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    final highlights = [
      {'icon': Icons.shopping_bag_outlined, 'text': 'Bulk Offers', 'bg': const Color(0xFFEEF2FF)},
      {'icon': Icons.auto_awesome, 'text': 'Attractive Discounts', 'bg': const Color(0xFFFFECEC)},
      {'icon': Icons.trending_up, 'text': 'Priority Processing', 'bg': const Color(0xFFE9FBF1)},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Features', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: highlights.map((h) {
              return Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: h['bg'] as Color, borderRadius: BorderRadius.circular(8)),
                      child: Icon(h['icon'] as IconData, size: 20, color: const Color(0xFF7C3AED)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      h['text'] as String,
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    final steps = [
      {'title': 'Submit Distributor Registration', 'desc': 'Register your organization to apply for distributor pricing access.', 'icon': Icons.person_add, 'color': const Color(0xFF7C3AED), 'hasAction': true},
      {'title': 'Receive Distributor ID & Unlock Pricing', 'desc': 'Once approved, receive your Distributor Registration ID via email. This ID activates your account and unlocks exclusive bulk pricing and higher discount tiers.', 'icon': Icons.mail_outline, 'color': const Color(0xFF4C42B8)},
      {'title': 'Select Discount / Denomination', 'desc': 'Pick discount & value', 'icon': Icons.tag, 'color': const Color(0xFFEC4899)},
      {'title': 'Add to Cart', 'desc': 'Review & confirm quantity', 'icon': Icons.shopping_cart_outlined, 'color': const Color(0xFF3B82F6)},
      {'title': 'Make Payment', 'desc': 'Secure & fast checkout', 'icon': Icons.credit_card, 'color': const Color(0xFF7C3AED)},
      {'title': 'Receive Multiple Voucher Orders', 'desc': 'Instant delivery to your dashboard', 'icon': Icons.mark_email_read, 'color': const Color(0xFFF97316)},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How it Works', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1F2937))),
          const SizedBox(height: 16),
          ...steps.map((step) => _buildStepCard(step)),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> step) {
    return GestureDetector(
      onTap: step['hasAction'] == true ? () => setState(() => _showContactModal = true) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Icon(step['icon'] as IconData, size: 20, color: step['color'] as Color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['title'] as String,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step['desc'] as String,
                    style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (step['hasAction'] == true)
              Text('Click here to proceed →', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
          ],
        ),
      ),
    );
  }

  Widget _buildContactModal() {
    return GestureDetector(
      onTap: _closeModal,
      child: Container(
        color: Colors.black45,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Get Registered', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
                        GestureDetector(
                          onTap: _closeModal,
                          child: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  if (_submitted)
                    _buildSuccessState()
                  else
                    _buildFormState(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 40, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 16),
          Text('We will get in touch with you', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text('Our team will contact you shortly regarding distributor onboarding.', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _closeModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildTextField('Enter Organisation Name', _orgNameController),
          const SizedBox(height: 12),
          _buildTextField('Enter City', _cityController),
          const SizedBox(height: 12),
          _buildTextField('Enter State', _stateController),
          const SizedBox(height: 12),
          _buildTextField('Enter PAN Number', _panController, maxLength: 10, uppercase: true),
          const SizedBox(height: 12),
          _buildTextField('Enter GST', _gstController, maxLength: 15, uppercase: true),
          const SizedBox(height: 12),
          _buildTextField('Tell us message', _messageController, maxLines: 3),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(_error!, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFFDC2626))),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Get Started', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {int maxLines = 1, int? maxLength, bool uppercase = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: uppercase ? TextCapitalization.characters : TextCapitalization.none,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: '',
      ),
    );
  }
}
