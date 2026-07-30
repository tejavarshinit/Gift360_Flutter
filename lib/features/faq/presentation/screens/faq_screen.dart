import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _faqCategories = [
  {'id': 'general', 'label': 'General', 'icon': Icons.help_outline, 'color': Colors.blue},
  {'id': 'orders', 'label': 'Orders & Payments', 'icon': Icons.shopping_cart_outlined, 'color': Colors.green},
  {'id': 'vouchers', 'label': 'Vouchers & Brands', 'icon': Icons.credit_card, 'color': Colors.purple},
  {'id': 'security', 'label': 'Security & Trust', 'icon': Icons.shield_outlined, 'color': Colors.orange},
  {'id': 'tech', 'label': 'Technical Support', 'icon': Icons.flash_on_outlined, 'color': Colors.amber},
  {'id': 'support', 'label': 'Customer Care', 'icon': Icons.chat_bubble_outline, 'color': Colors.red},
];

const _faqData = {
  'general': [
    {'q': 'What is Gift360?', 'a': "Gift360 is India's leading digital gifting platform where you can buy, send, and manage gift vouchers from over 200+ top brands instantly."},
    {'q': 'How do I create an account?', 'a': "Click on the 'Sign In' button, select 'Register', and enter your mobile number or email address to get started."},
    {'q': 'Is there a mobile app available?', 'a': 'Yes, Gift360 is available on both iOS and Android. You can download it from the App Store or Google Play Store.'},
    {'q': 'Are there any membership fees?', 'a': 'No, joining Gift360 is completely free. You only pay for the gift vouchers you purchase.'},
    {'q': 'How do I contact customer support?', 'a': 'You can reach us via the Support category on this FAQ page, or email us at support@gift360.io.'},
  ],
  'orders': [
    {'q': 'How can I pay for my vouchers?', 'a': 'We support all major payment methods including UPI, Credit/Debit Cards, Net Banking, and various digital wallets.'},
    {'q': 'How long does it take to receive my voucher?', 'a': 'Digital vouchers are delivered instantly to your registered email and mobile number via SMS as soon as the payment is confirmed.'},
    {'q': 'Can I get a refund for a purchased voucher?', 'a': "Due to the nature of digital products, vouchers are generally non-refundable once issued. However, our support team will assist with technical issues."},
  ],
  'vouchers': [
    {'q': 'How do I redeem my gift voucher?', 'a': "Each brand has its own redemption process. Generally, you can use the voucher code at the brand's physical store or website during checkout."},
    {'q': 'What is the validity of the vouchers?', 'a': "Validity varies by brand, usually ranging from 3 to 12 months. You can check the exact expiry date in your 'My Vouchers' section."},
    {'q': 'Can I send a voucher to someone else?', 'a': "Absolutely! During the purchase process, you can select 'Gift this item', enter the recipient's details, and we'll deliver it directly to them."},
  ],
  'security': [
    {'q': 'Is my payment information safe?', 'a': 'Yes, we use industry-standard SSL encryption and PCI-DSS compliant payment gateways to ensure your financial data is 100% secure.'},
    {'q': 'What should I do if I suspect a fraudulent transaction?', 'a': 'Immediately contact our support team at support@gift360.io and notify your bank.'},
  ],
  'tech': [
    {"q": "I didn't receive the OTP, what should I do?", 'a': "Please wait for 60 seconds and try 'Resend OTP'. Ensure you have a stable network connection."},
    {'q': 'The website is slow on my browser.', 'a': 'We recommend using the latest version of Chrome, Safari, or Firefox. Clearing your browser cache can also help.'},
    {'q': 'What should I do if the website crashes during payment?', 'a': "Don't worry. If your money is debited, it will be refunded automatically within 5-7 business days."},
  ],
  'support': [
    {'q': 'How do I track my order status?', 'a': "You can track your order in the 'My Orders' section of your profile. We also send real-time updates via SMS and Email."},
    {'q': 'Can I cancel my voucher order?', 'a': 'Orders for digital vouchers cannot be cancelled once the code has been generated and delivered.'},
    {'q': 'Are there any hidden charges?', 'a': 'No, the price you see on the brand page is inclusive of all taxes. There are no hidden processing fees.'},
  ],
};

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _searchQuery = '';
  String _activeCategory = 'general';
  bool _showQueryDialog = false;

  @override
  Widget build(BuildContext context) {
    final isSearching = _searchQuery.trim().isNotEmpty;
    final searchResults = isSearching
        ? _faqData.entries.expand((e) => e.value.map((item) => {...item, 'category': e.key})).where((item) {
            final q = _searchQuery.toLowerCase();
            return item['q']!.toLowerCase().contains(q) || item['a']!.toLowerCase().contains(q);
          }).toList()
        : <Map<String, String>>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E3E3E)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Help & FAQ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF3E3E3E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search questions...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF6C5CE7)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Category chips (horizontal scroll)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _faqCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _faqCategories[index];
                    final active = _activeCategory == cat['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategory = cat['id'] as String),
                      child: Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: active ? const Color(0xFF6C5CE7) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: active ? const Color(0xFF6C5CE7) : Colors.grey.shade200),
                          boxShadow: active ? [BoxShadow(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3), blurRadius: 10)] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat['icon'] as IconData, size: 24, color: active ? Colors.white : (cat['color'] as Color)),
                            const SizedBox(height: 6),
                            Text(
                              (cat['label'] as String).split(' ').first,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : const Color(0xFF3E3E3E),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // FAQ list or search results
              Expanded(
                child: isSearching
                    ? _buildSearchResults(searchResults)
                    : _buildCategoryFaq(),
              ),
            ],
          ),
          if (_showQueryDialog)
            GestureDetector(
              onTap: () => setState(() => _showQueryDialog = false),
              child: Container(
                color: Colors.black45,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Drop a Query', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text('Send us a message and we\'ll get back to you.', style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 16),
                          const TextField(decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          const TextField(decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          const TextField(maxLines: 3, decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => setState(() => _showQueryDialog = false),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7), foregroundColor: Colors.white),
                              child: const Text('Send Message'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomSheet: _buildQueryButton(),
    );
  }

  Widget _buildSearchResults(List<Map<String, String>> results) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No results found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Try a different keyword', style: TextStyle(color: Colors.grey.shade500)),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) => _buildFaqItem(results[index]['q']!, results[index]['a']!),
    );
  }

  Widget _buildCategoryFaq() {
    final items = _faqData[_activeCategory] ?? [];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildFaqItem(items[index]['q']!, items[index]['a']!),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
        iconColor: const Color(0xFF6C5CE7),
        children: [
          Text(answer, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildQueryButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => setState(() => _showQueryDialog = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Drop a Query', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
