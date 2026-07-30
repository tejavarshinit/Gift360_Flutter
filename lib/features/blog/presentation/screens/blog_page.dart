import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BlogPage extends StatelessWidget {
  const BlogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => context.pop(),
        ),
        title: const Text('Insights & Updates', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0x1A6C5CE7), Color(0x0AEF4444)]),
              ),
              child: const Column(
                children: [
                  Text('Insights & Updates', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                  SizedBox(height: 8),
                  Text('Your daily dose of voucher news, upcoming offers, and site improvements.', style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                ],
              ),
            ),

            // Trending Updates
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.red, size: 28),
                      const SizedBox(width: 8),
                      const Text('Trending Updates', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Fire News', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7))),
                  const SizedBox(height: 12),
                  ..._fireNews.take(4).map((news) => _buildBlogCard(context, news)),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0x666C5CE7))),
                      child: const Text('Show More', style: TextStyle(color: Color(0xFF6C5CE7))),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upcoming
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch, color: Color(0xFF6C5CE7), size: 28),
                      const SizedBox(width: 8),
                      const Text('Upcoming Updates', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._upcomingUpdates.map((u) => _buildUpdateCard(u)),
                  const SizedBox(height: 24),

                  // Changelogs
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.grey, size: 28),
                            const SizedBox(width: 8),
                            const Text('Site Changelogs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._changelogs.map((log) => _buildChangelog(log)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlogCard(BuildContext context, Map<String, String> news) {
    return GestureDetector(
      onTap: () => context.push('/blogs/0'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF6C5CE7).withValues(alpha: 0.3), const Color(0xFFEC4899).withValues(alpha: 0.3)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(child: Icon(Icons.article, size: 48, color: const Color(0xFF6C5CE7).withValues(alpha: 0.5))),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(news['category']!, style: const TextStyle(fontSize: 10, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(news['date']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(news['title']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(news['description']!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  const Text('Read More →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> update) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: Color(0xFF6C5CE7), width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0x1A6C5CE7), borderRadius: BorderRadius.circular(8)),
            child: Icon(update['icon'] as IconData, color: const Color(0xFF6C5CE7), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(update['date'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(update['status'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangelog(Map<String, dynamic> log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                child: Text(log['version'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(log['date'] as String, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          ...((log['changes'] as List<String>).map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF6C5CE7), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(c, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ))),
        ],
      ),
    );
  }

  static final _fireNews = [
    {'title': 'The Rise of Digital Gifting in 2026', 'description': 'How digital vouchers are transforming the way we celebrate special occasions.', 'date': 'Jan 10, 2026', 'category': 'Trends', 'image': ''},
    {'title': 'Maximizing Rewards with Gift360 Vouchers', 'description': 'A complete guide to getting the most value out of every purchase.', 'date': 'Jan 08, 2026', 'category': 'Guide', 'image': ''},
    {'title': 'Security Tips for Online Voucher Shopping', 'description': 'Protect your gift cards and personal information from common online scams.', 'date': 'Jan 05, 2026', 'category': 'Security', 'image': ''},
    {'title': 'Top 10 Gift Cards for Gamers in 2026', 'description': 'Discover which gaming vouchers are trending this year among enthusiasts.', 'date': 'Jan 03, 2026', 'category': 'Gaming', 'image': ''},
    {'title': 'Sustainability in Digital Payments', 'description': 'How eco-friendly initiatives are shaping the future of digital transactions.', 'date': 'Jan 01, 2026', 'category': 'Eco', 'image': ''},
    {'title': 'Global Gift Card Market Trends', 'description': 'An analysis of the worldwide demand for prepaid and store cards.', 'date': 'Dec 30, 2025', 'category': 'Finance', 'image': ''},
  ];

  static final _upcomingUpdates = [
    {'title': 'New Luxury Brand Vouchers', 'date': 'Expected: Feb 2026', 'status': 'Coming Soon', 'icon': Icons.star},
    {'title': 'Gift360 Mobile App Launch', 'date': 'Expected: Q1 2026', 'status': 'In Development', 'icon': Icons.rocket_launch},
    {'title': 'Enhanced Wallet Integration', 'date': 'Expected: Mar 2026', 'status': 'Planned', 'icon': Icons.card_giftcard},
    {'title': 'Referral Program 2.0', 'date': 'Expected: Apr 2026', 'status': 'Coming Soon', 'icon': Icons.trending_up},
    {'title': 'International Brands Expansion', 'date': 'Expected: May 2026', 'status': 'Planned', 'icon': Icons.public},
  ];

  static final _changelogs = [
    {'version': 'v2.1.0', 'date': 'Jan 2026', 'changes': ['Improved checkout flow', 'Added dynamic hero banners', 'Bug fixes for mobile navigation']},
    {'version': 'v2.0.5', 'date': 'Dec 2025', 'changes': ['Dark mode support', 'Performance optimizations', 'New filtering system']},
  ];
}
