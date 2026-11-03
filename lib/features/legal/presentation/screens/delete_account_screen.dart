import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('Delete Account', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete Your Gift360 Account',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6),
                  children: [
                    TextSpan(
                      text:
                          'To request deletion of your Gift360 account and associated data, please email ',
                    ),
                    TextSpan(
                      text: 'gift360@gift360.io',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    TextSpan(text: ' using your registered email address.'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Our support team will assist you with the account deletion process.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563), height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
