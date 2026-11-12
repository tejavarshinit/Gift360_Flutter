import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:gift360/config/app_config.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/rewards/presentation/providers/rewards_provider.dart';
import 'package:gift360/features/orders/presentation/providers/orders_provider.dart';
import 'package:gift360/features/orders/data/models/voucher_view.dart';
import 'package:gift360/core/widgets/gift_header.dart';
import 'package:gift360/core/constants/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditingName = false;
  late TextEditingController _nameController;
  int _selectedTab = 0; // 0 = Profile, 1 = Rewards
  Timer? _rewardsTimer;
  int _rewardsTick = 0;
  bool _biometricActionLoading = false;
  String? _biometricEnrollmentIssue;
  String? _biometricActionError;
  String? _biometricClientId;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _restoreDisplayName(user);
    if (AppConfig.biometricLoginEnabled) _loadBiometricEnrollment();

    // Rewards tab: 1s countdown refresh + 10s status re-fetch (matches React).
    _rewardsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _selectedTab != 1) return;
      setState(() => _rewardsTick++);
      if (_rewardsTick % 10 == 0) {
        ref.invalidate(rewardStatusProvider);
      }
    });
  }

  Future<void> _loadBiometricEnrollment() async {
    try {
      final state = await ref.read(biometricServiceProvider).enrollmentState();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _biometricClientId = state.enrollment?.clientId;
          _biometricEnrollmentIssue = state.issue;
        });
      });
    } catch (error) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _biometricEnrollmentIssue = error.toString());
      });
    }
  }

  Future<void> _toggleBiometricLogin(dynamic user) async {
    setState(() => _biometricActionLoading = true);
    try {
      final service = ref.read(biometricServiceProvider);
      if (_biometricClientId == user.clientId) {
        await service.disable(clientId: user.clientId, token: user.token);
        _biometricClientId = null;
      } else {
        await service.enable(clientId: user.clientId, token: user.token);
        _biometricClientId = user.clientId;
      }
      _biometricEnrollmentIssue = null;
      _biometricActionError = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _biometricClientId == null
                  ? 'Biometric login disabled.'
                  : 'Biometric login enabled.',
            ),
          ),
        );
      }
    } catch (error) {
      _biometricActionError = error.toString();
    } finally {
      if (mounted) setState(() => _biometricActionLoading = false);
    }
  }

  Future<void> _recoverBiometricLogin(dynamic user) async {
    setState(() => _biometricActionLoading = true);
    try {
      await ref
          .read(biometricServiceProvider)
          .recoverAfterOtp(clientId: user.clientId, token: user.token);
      if (mounted) {
        setState(() {
          _biometricClientId = null;
          _biometricEnrollmentIssue = null;
          _biometricActionError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric enrollment removed.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _biometricActionError = error.toString());
      }
    } finally {
      if (mounted) setState(() => _biometricActionLoading = false);
    }
  }

  Future<void> _restoreDisplayName(dynamic user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('displayName');
      if (saved != null && saved.isNotEmpty && mounted) {
        _nameController.text = saved;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _rewardsTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    final user = ref.read(authProvider);
    if (user == null) return;

    // Save to SharedPreferences (matches React's localStorage.displayName)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('displayName', newName);

    // Update auth user
    ref.read(authProvider.notifier).setUser(user.copyWith(name: newName));

    setState(() => _isEditingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final walletAsync = ref.watch(walletBalanceProvider);
    final supercoinState = ref.watch(supercoinProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FF),
        appBar: const GiftHeader(),
        body: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 600 ? 48.0 : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  28,
                  horizontalPadding,
                  120,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _buildGuestAccountLanding(context),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    final balance = walletAsync.value?.totalBalance ?? 0;
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim().characters.first.toUpperCase()
        : 'U';

    final ordersAsync = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildAccountHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      children: [
                        _buildUserSummaryCard(user, initial),
                        const SizedBox(height: 12),
                        _buildBalanceCards(balance, supercoinState.balance),
                        const SizedBox(height: 16),
                        _buildAccountMenu(context),
                        if (_selectedTab == 1) ...[
                          const SizedBox(height: 16),
                          _buildRewardsPanel(),
                        ],
                        const SizedBox(height: 16),
                        _buildProfileDetailsCard(user),
                        const SizedBox(height: 16),
                        _buildPastOrdersCard(context, ordersAsync),
                        const SizedBox(height: 16),
                        _buildLogoutCard(context),
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

  Widget _buildAccountHeader(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECE8F4))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Go back',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, size: 21),
          ),
          Text(
            'MY ACCOUNT',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: .5),
          ),
          TextButton.icon(
            onPressed: _showContactDialog,
            icon: const Icon(Icons.help_outline, size: 17),
            label: const Text('Help'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryPurple,
              textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSummaryCard(dynamic user, String initial) {
    return _accountCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: AppColors.profileAvatarBg,
            child: Text(initial, style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isEditingName)
                  SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      onSubmitted: (_) => _saveDisplayName(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                        suffixIcon: IconButton(
                          tooltip: 'Save name',
                          onPressed: _saveDisplayName,
                          icon: const Icon(Icons.check, size: 18, color: AppColors.primaryPurple),
                        ),
                      ),
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(user.email.isEmpty ? 'Email unavailable' : user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mutedText()),
                Text(user.mobile.isEmpty ? 'Phone unavailable' : user.mobile, style: _mutedText()),
              ],
            ),
          ),
          if (_isEditingName)
            IconButton(
              tooltip: 'Cancel',
              onPressed: () => setState(() {
                _isEditingName = false;
                _nameController.text = user.name;
              }),
              icon: const Icon(Icons.close, size: 18),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _nameController.text = user.name;
                _nameController.selection = TextSelection.collapsed(
                  offset: _nameController.text.length,
                );
                _isEditingName = true;
              }),
              child: Text(
                'Edit',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBalanceCards(double balance, dynamic superCoins) {
    return Row(
      children: [
        Expanded(child: _accountMetric('Balance', '₹${balance.toStringAsFixed(2)}')),
        const SizedBox(width: 12),
        Expanded(
          child: _accountMetric(
            'SuperCoins',
            '${(superCoins as num).toInt()}',
            accent: true,
            icon: 'assets/images/SuperCOin-removebg-preview.png',
          ),
        ),
      ],
    );
  }

  Widget _accountMetric(
    String label,
    String value, {
    bool accent = false,
    String? icon,
  }) {
    return _accountCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _mutedText(fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (icon != null) ...[
                Image.asset(icon, width: 20, height: 20),
                const SizedBox(width: 5),
              ],
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accent ? AppColors.primaryPurple : const Color(0xFF30284A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountMenu(BuildContext context) {
    return _accountCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _accountMenuRow(Icons.person_outline, 'Profile details', 'Name, email and phone number', () => setState(() => _selectedTab = 0)),
          _accountMenuRow(
            Icons.monetization_on_outlined,
            'Rewards / SuperCoins',
            'View your rewards balance',
            () => setState(() => _selectedTab = 1),
            assetIcon: 'assets/images/SuperCOin-removebg-preview.png',
          ),
          _accountMenuRow(Icons.card_giftcard_outlined, 'My Vouchers', 'Open your purchased and redeemed vouchers', () => context.push('/orders')),
          _accountMenuRow(Icons.storefront_outlined, 'Partner with us', 'Sell gift vouchers at your own margins', () => context.push('/reseller')),
          _accountMenuRow(Icons.mail_outline, 'Contact Us', 'Get help with vouchers or payments', _showContactDialog),
        ],
      ),
    );
  }

  Widget _accountMenuRow(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    String? assetIcon,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0ECF8)))),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.primaryPurple.withValues(alpha: .1), shape: BoxShape.circle),
              child: assetIcon == null
                  ? Icon(icon, size: 20, color: AppColors.primaryPurple)
                  : Padding(
                      padding: const EdgeInsets.all(9),
                      child: Image.asset(assetIcon),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _mutedText(fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFA59BBE)),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardsPanel() {
    return _accountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/SuperCOin-removebg-preview.png',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Rewards & SuperCoins',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              TextButton(onPressed: () => setState(() => _selectedTab = 0), child: const Text('Back')),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: _buildRewardsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsCard(dynamic user) {
    return _accountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile details', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildLightField('Email', user.email),
          const SizedBox(height: 12),
          _buildLightField('Phone Number', user.mobile),
          if (AppConfig.biometricLoginEnabled) ...[
            const SizedBox(height: 16),
            _buildBiometricLoginAction(user),
          ],
        ],
      ),
    );
  }

  Widget _buildLightField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _mutedText(fontSize: 11)),
        const SizedBox(height: 7),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFF8F7FB), border: Border.all(color: const Color(0xFFE8E3F2)), borderRadius: BorderRadius.circular(10)),
          child: Text(value.isEmpty ? 'Unavailable' : value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  Widget _buildPastOrdersCard(BuildContext context, AsyncValue<OrdersData> ordersAsync) {
    return _accountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Past Orders', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
              TextButton(onPressed: () => context.push('/orders'), child: const Text('View all')),
            ],
          ),
          const SizedBox(height: 4),
          ordersAsync.when(
            loading: () => Column(children: List.generate(2, (_) => _orderSkeleton())),
            error: (_, _) => _orderMessage('Unable to load orders right now.', isError: true),
            data: (data) {
              final orders = data.allOrders.take(3).toList();
              if (orders.isEmpty) return _orderMessage('No orders yet.');
              return Column(children: orders.map((order) => _orderPreview(order)).toList());
            },
          ),
        ],
      ),
    );
  }

  Widget _orderSkeleton() {
    return Container(
      height: 82,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(color: const Color(0xFFF0ECF8), borderRadius: BorderRadius.circular(14)),
    );
  }

  Widget _orderMessage(String text, {bool isError = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isError ? const Color(0xFFFFF1F2) : const Color(0xFFF8F7FB), borderRadius: BorderRadius.circular(12)),
      child: Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: isError ? Colors.red.shade700 : const Color(0xFF81789A))),
    );
  }

  Widget _orderPreview(Map<String, dynamic> order) {
    final items = order['items'] is List ? List<Map<String, dynamic>>.from((order['items'] as List).whereType<Map>()) : <Map<String, dynamic>>[];
    final meta = items.isNotEmpty && items.first['meta'] is Map ? Map<String, dynamic>.from(items.first['meta'] as Map) : <String, dynamic>{};
    final merchant = meta['brand_name']?.toString() ?? meta['brandName']?.toString() ?? 'Gift voucher';
    final amount = order['pricing'] is Map ? (order['pricing'] as Map)['final_payable'] ?? (order['pricing'] as Map)['subtotal'] : order['total_amount'];
    final date = orderCreatedAt(order);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE8E3F2)), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              _buildOrderImage(meta),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(merchant, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${items.length} ${items.length == 1 ? 'item' : 'items'} · ${date ?? 'Date unavailable'}', style: _mutedText(fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: AppColors.primaryPurple.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
                child: Text((order['status'] ?? 'PROCESSING').toString(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryPurple)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total bill', style: _mutedText(fontSize: 12)),
            Text('₹${amount ?? 0}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ],
      ),
    );
  }

  Widget _buildOrderImage(Map<String, dynamic> meta) {
    final imageUrl = orderItemImageUrl(meta);
    return Container(
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: imageUrl == null
          ? const Icon(Icons.card_giftcard, color: AppColors.primaryPurple)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.card_giftcard,
                color: AppColors.primaryPurple,
              ),
            ),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        ref.read(authProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
      icon: const Icon(Icons.logout, size: 17),
      label: const Text('Log out'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: Colors.red.shade600,
        side: BorderSide(color: Colors.red.shade200),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _accountCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(16), Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8E3F2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  TextStyle _mutedText({double fontSize = 12}) => GoogleFonts.poppins(fontSize: fontSize, color: const Color(0xFF81789A));

  Widget _buildGuestAccountLanding(BuildContext context) {
    final textTheme = GoogleFonts.poppins();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDCD2FF)),
          ),
          child: Column(
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: .16),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 68,
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Your Account',
                textAlign: TextAlign.center,
                style: textTheme.copyWith(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF28165F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everything you love, all in one place.',
                textAlign: TextAlign.center,
                style: textTheme.copyWith(
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF665A83),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE7E1F7)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F3F1A55),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildGuestFeatureRow(
                icon: Icons.local_offer_outlined,
                title: '370+ brand vouchers',
                color: AppColors.primaryPurple,
              ),
              _buildGuestFeatureDivider(),
              _buildGuestFeatureRow(
                icon: Icons.bolt_outlined,
                title: 'Instant delivery',
                color: AppColors.primaryPurple,
              ),
              _buildGuestFeatureDivider(),
              _buildGuestFeatureRow(
                icon: Icons.monetization_on_outlined,
                title: 'SuperCoins cashback rewards',
                color: AppColors.primaryPurple,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              elevation: 5,
              shadowColor: AppColors.primaryPurple.withValues(alpha: .28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Sign in / Create account',
              style: textTheme.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to unlock your personalised Gift360 experience.',
          textAlign: TextAlign.center,
          style: textTheme.copyWith(
            fontSize: 11,
            color: const Color(0xFF81789A),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestFeatureRow({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF332A4A),
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Color(0xFFAAA1BD),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestFeatureDivider() {
    return const Divider(height: 1, indent: 56, color: Color(0xFFF0ECF7));
  }

  Widget _buildBiometricLoginAction(dynamic user) {
    final belongsToOtherAccount =
        _biometricClientId != null && _biometricClientId != user.clientId;
    final enabledForUser = _biometricClientId == user.clientId;
    final label = belongsToOtherAccount
        ? 'Biometric login is enrolled for another account'
        : enabledForUser
        ? 'Disable biometric login'
        : 'Enable biometric login';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed:
              _biometricActionLoading ||
                  belongsToOtherAccount ||
                  _biometricEnrollmentIssue != null
              ? null
              : () => _toggleBiometricLogin(user),
          icon: _biometricActionLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fingerprint),
          label: Text(label),
        ),
        if (_biometricEnrollmentIssue != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              children: [
                Text(
                  _biometricEnrollmentIssue!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                TextButton(
                  onPressed: _biometricActionLoading
                      ? null
                      : () => _recoverBiometricLogin(user),
                  child: const Text('Remove invalid enrollment after sign-in'),
                ),
              ],
            ),
          ),
        if (_biometricActionError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _biometricActionError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRewardsTab() {
    final rewardAsync = ref.watch(rewardStatusProvider);
    return SingleChildScrollView(
      child: rewardAsync.when(
        loading: () => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Loading rewards.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
          ),
        ),
        error: (_, _) => _rewardsEmptyState(),
        data: (reward) {
          if (reward == null || reward['hasReward'] != true) {
            return _rewardsEmptyState();
          }
          return _rewardsStatusCard(reward);
        },
      ),
    );
  }

  Widget _rewardsEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.card_giftcard,
          size: 48,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 16),
        Text(
          'No rewards yet',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A Dussehra quiz offer appears after a payment cancellation.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }

  int _remainingSeconds(String? iso) {
    final deadline = DateTime.tryParse(iso ?? '');
    if (deadline == null) return 0;
    final diff = deadline.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '${minutes}m ${seconds}s';
  }

  Widget _rewardsStatusCard(Map<String, dynamic> reward) {
    final status = (reward['status'] ?? '').toString().toUpperCase();
    final coins = (reward['coinReward'] as num?)?.toInt() ?? 5;
    final secondsLeft = _remainingSeconds(
      status == 'PENDING'
          ? reward['expiresAt']?.toString()
          : reward['quizStartExpiresAt']?.toString(),
    );

    final countdownStyle = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: const Color(0xFFFCD34D),
    );

    if (status == 'PENDING') {
      return _rewardsCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: Color(0xFFC4B5FD),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$coins bonus SuperCoins available',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Complete a new purchase in this window; the bonus is added automatically after successful payment and voucher fulfillment.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 13,
                  color: Color(0xFFFCD34D),
                ),
                const SizedBox(width: 4),
                Text(
                  secondsLeft > 0
                      ? 'Purchase within ${_formatCountdown(secondsLeft)}'
                      : 'Bonus window expired',
                  style: countdownStyle,
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (status == 'REDEEMED' || status == 'CLAIMED') {
      final orderNumber = reward['redeemedOrderNumber']?.toString();
      final redeemedAt = DateTime.tryParse(
        reward['redeemedAt']?.toString() ?? '',
      );
      return _rewardsCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 20,
                  color: Color(0xFF34D399),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$coins SuperCoins earned',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${orderNumber != null && orderNumber.isNotEmpty ? 'Credited with order $orderNumber' : 'Your reward has been credited.'}'
              '${redeemedAt != null ? ' • ${DateFormat('d MMM yyyy, h:mm a').format(redeemedAt.toLocal())}' : ''}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (status == 'EXPIRED') {
      return _rewardsCentered(
        icon: Icons.access_time,
        text: 'Your Dussehra quiz reward expired unused.',
      );
    }

    if (status == 'LOST') {
      return _rewardsCentered(
        icon: Icons.sentiment_dissatisfied,
        text: 'All answers must be correct to earn the $coins SuperCoins.',
      );
    }

    return _rewardsCard(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Color(0xFFFCD34D)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dussehra quiz offer is active',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Return to the payment result to start or continue the quiz.',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatCountdown(secondsLeft)} remaining',
            style: countdownStyle,
          ),
        ],
      ),
    );
  }

  Widget _rewardsCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: child,
    );
  }

  Widget _rewardsCentered({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need help?',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Having a voucher or payment issue? We\'re here to help.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showContactDialog(),
            child: Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mail_outline,
                    size: 14,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Contact Us',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(text: 'For any queries, reach out to '),
                    TextSpan(
                      text: 'gift360@gift360.io',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Note: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const TextSpan(
                      text:
                          'If a transaction was successful but the voucher was not generated, please share the details at ',
                    ),
                    TextSpan(
                      text: 'gift360@gift360.io',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7C3AED),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const TextSpan(text: ' for quick action on the issue.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Got it',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    String value,
    bool isEditing,
    VoidCallback onEdit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
            if (isEditing)
              Row(
                children: [
                  GestureDetector(
                    onTap: _saveDisplayName,
                    child: const Icon(
                      Icons.check,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditingName = false;
                        _nameController.text = value;
                      });
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                ],
              )
            else
              GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit, color: Colors.white70, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: isEditing
              ? TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
              ],
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 174,
        height: 44,
        child: ElevatedButton(
          onPressed: () async {
            ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF06DA6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 15),
              SizedBox(width: 5),
              Text(
                'Log Out',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
