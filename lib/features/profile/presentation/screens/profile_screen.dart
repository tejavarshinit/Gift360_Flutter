import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:gift360/features/supercoin/presentation/providers/supercoin_provider.dart';
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

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _restoreDisplayName(user);
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
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 48, color: Colors.amber),
                const SizedBox(height: 12),
                Text('Rewards & Quiz',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text('Complete quizzes and earn cashback rewards!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Navigate to spin wheel or quiz
                    context.push('/spin-wheel');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Spin & Win'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Feedback section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.feedback_outlined, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Share Feedback', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('Help us improve Gift360', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        clipBehavior: Clip.antiAlias,
                        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                        child: const FeedbackForm(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chevron_right, color: Colors.white70),
                ),
              ],
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
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Need help?', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _showContactDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail_outline, size: 20, color: Colors.white70),
                  const SizedBox(width: 12),
                  Text('Contact Us', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white70),
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
      builder: (ctx) => AlertDialog(
        title: const Text('Contact Us'),
        content: const Text('For any transaction issues or support, please email us at:\n\nsupport@sabbpe.com'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse('mailto:support@sabbpe.com');
              try {
                await launchUrl(uri);
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to open email client')),
                  );
                }
              }
            },
            child: const Text('Email Us'),
          ),
        ],
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
