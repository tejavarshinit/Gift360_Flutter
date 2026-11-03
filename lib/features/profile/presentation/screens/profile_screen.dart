import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
import 'package:gift360/features/rewards/presentation/providers/rewards_provider.dart';
import 'package:gift360/features/support/presentation/providers/support_ticket_provider.dart';
import 'package:gift360/features/feedback/presentation/widgets/feedback_form.dart';
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

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _restoreDisplayName(user);

    // Rewards tab: 1s countdown refresh + 10s status re-fetch (matches React).
    _rewardsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _selectedTab != 1) return;
      setState(() => _rewardsTick++);
      if (_rewardsTick % 10 == 0) {
        ref.invalidate(rewardStatusProvider);
      }
    });
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
        body: Center(
          child: ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('Login / Register'),
          ),
        ),
      );
    }

    final balance = walletAsync.value?.totalBalance ?? 0;
    final initial = user.name.trim().isNotEmpty
        ? user.name.trim().characters.first.toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => context.pop(),
                  ),
                ),
                const SizedBox(height: 8),
                CircleAvatar(
                  radius: 43,
                  backgroundColor: const Color(0xFFDF9CA9),
                  child: Text(initial, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 18),
                Text(user.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: Color(0xFF454545))),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7357F1), Color(0xFF5040A0), Color(0xFF3B327D)],
                ),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(34), topRight: Radius.circular(34)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 18),
              child: Column(
                children: [
                  // Tab switcher
                  _buildTabSwitcher(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _selectedTab == 0
                        ? _buildProfileTab(user, balance, supercoinState)
                        : _buildRewardsTab(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('Profile',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 0 ? const Color(0xFF523DA9) : Colors.white70)),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('Rewards',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 1 ? const Color(0xFF523DA9) : Colors.white70)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(dynamic user, double balance, SuperCoinState supercoinState) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Editable username
          _buildEditableField('Username', user.name, _isEditingName, () {
            setState(() => _isEditingName = true);
          }),
          const SizedBox(height: 20),
          _buildField('Email', user.email),
          const SizedBox(height: 20),
          _buildField('Phone Number', user.mobile),
          const SizedBox(height: 20),
          _buildField('Balance', '₹${balance.toStringAsFixed(2)}'),
          const SizedBox(height: 20),
          // SuperCoin balance
          _buildField('SuperCoins', '${supercoinState.balance.toInt()} coins',
              icon: Icons.monetization_on, iconColor: Colors.amber),
          const SizedBox(height: 30),
          // Contact Us section
          _buildContactSection(),
          const SizedBox(height: 20),
          _buildLogoutButton(context),
        ],
      ),
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
        error: (_, __) => _rewardsEmptyState(),
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
        Icon(Icons.card_giftcard, size: 48, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(
          'No rewards yet',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
                const Icon(Icons.card_giftcard, size: 20, color: Color(0xFFC4B5FD)),
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
                const Icon(Icons.access_time, size: 13, color: Color(0xFFFCD34D)),
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
      final redeemedAt = DateTime.tryParse(reward['redeemedAt']?.toString() ?? '');
      return _rewardsCard(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, size: 20, color: Color(0xFF34D399)),
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
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8)),
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
          Text('Need help?',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Having a voucher or payment issue? We\'re here to help.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70, height: 1.4)),
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
                  const Icon(Icons.mail_outline, size: 14, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 6),
                  Text('Contact Us',
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF7C3AED))),
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
                child: const Icon(Icons.mail_outline, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Contact Us',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
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
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
                  children: [
                    const TextSpan(
                      text: 'Note: ',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7C3AED)),
                    ),
                    const TextSpan(text: 'If a transaction was successful but the voucher was not generated, please share the details at '),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: const Text('Got it', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, String value, bool isEditing, VoidCallback onEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white)),
            if (isEditing)
              Row(
                children: [
                  GestureDetector(
                    onTap: _saveDisplayName,
                    child: const Icon(Icons.check, color: Colors.greenAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isEditingName = false;
                        _nameController.text = value;
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.redAccent, size: 20),
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: isEditing
              ? TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                )
              : Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
        ),
      ],
    );
  }

  Widget _buildField(String label, String value, {IconData? icon, Color? iconColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.white)),
        const SizedBox(height: 8),
        Container(
          height: 44,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
              ],
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF333333))),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 15),
              SizedBox(width: 5),
              Text('Log Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
