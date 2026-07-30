import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/wallet/presentation/providers/wallet_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final walletAsync = ref.watch(walletBalanceProvider);

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
          // Header with back button and avatar
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
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF454545),
                  ),
                ),
              ],
            ),
          ),
          // Profile form
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF7357F1), Color(0xFF5040A0), Color(0xFF3B327D)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(34),
                  topRight: Radius.circular(34),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 18),
              child: Column(
                children: [
                  _buildField('Username', user.name),
                  const SizedBox(height: 20),
                  _buildField('Email', user.email),
                  const SizedBox(height: 20),
                  _buildField('Phone Number', user.mobile),
                  const SizedBox(height: 20),
                  _buildField('Balance', '₹${balance.toStringAsFixed(2)}'),
                  const SizedBox(height: 30),
                  _buildLogoutButton(context, ref),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
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
          child: Text(
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

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Center(
      child: SizedBox(
        width: 174,
        height: 44,
        child: ElevatedButton(
          onPressed: () async {
            ref.read(authProvider.notifier).logout();
            if (context.mounted) {
              context.go('/login');
            }
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
