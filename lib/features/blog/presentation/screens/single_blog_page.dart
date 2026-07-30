import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SingleBlogPage extends StatelessWidget {
  final int id;
  const SingleBlogPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text('Blog', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Row(
              children: [
                GestureDetector(onTap: () => context.go('/'), child: const Text('Home', style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 12))),
                const Text(' / ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                GestureDetector(onTap: () => context.push('/blogs'), child: const Text('Blogs', style: TextStyle(color: Color(0xFF6C5CE7), fontSize: 12))),
                const Text(' / ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const Text('The Rise of Digital Gifting in 2026', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x1A6C5CE7), borderRadius: BorderRadius.circular(8)),
              child: const Text('Trends', style: TextStyle(fontSize: 12, color: Color(0xFF6C5CE7), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'The Rise of Digital Gifting in 2026',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
            ),
            const SizedBox(height: 16),

            // Author / date / read time
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0x1A6C5CE7),
                  child: const Text('A', style: TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Text('Ajay Sharma', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 16),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('Jan 10, 2026', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('5 min read', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(height: 20),

            // Hero image placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF6C5CE7).withValues(alpha: 0.3), const Color(0xFFEC4899).withValues(alpha: 0.3)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: Icon(Icons.article, size: 64, color: Colors.white)),
            ),
            const SizedBox(height: 24),

            // Content
            const Text(
              'Digital vouchers are no longer just a last-minute gift option. In 2026, they have become the primary way people celebrate milestones, show appreciation, and share joy across borders.',
              style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            const Text('Changing Consumer Behavior', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'The shift towards digital-first experiences has been accelerating for years. Today\'s consumers value convenience and personalization above all else. A digital gift card, delivered instantly with a personalized video message, resonates far more than a physical item that might take days to arrive.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: const Color(0xFF6C5CE7), width: 4)),
                color: const Color(0x0A6C5CE7),
              ),
              child: const Text(
                '"Digital gifting is not just about the transaction; it\'s about the connection that happens in the moment of delivery."',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 20),
            const Text('The Power of Choice', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'One of the greatest advantages of digital vouchers is the flexibility they provide. Instead of guessing what someone might want, givers provide the power of choice. This reduces waste and ensures that every gift is something the recipient truly values.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            const Text('Looking Ahead', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'As we look further into 2026, we expect to see even more integration with augmented reality and blockchain technology to make gift cards more interactive and secure. SabbPe is at the forefront of these innovations, ensuring our users always have the best gifting experience.',
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                _buildActionChip(Icons.thumb_up_outlined, '124'),
                const SizedBox(width: 12),
                _buildActionChip(Icons.comment_outlined, '18'),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0x336C5CE7))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Back button
            TextButton.icon(
              onPressed: () => context.push('/blogs'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Blogs'),
            ),
            const SizedBox(height: 24),

            // Comments
            Row(
              children: [
                const Icon(Icons.comment, color: Color(0xFF6C5CE7), size: 24),
                const SizedBox(width: 8),
                const Text('Comments (2)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            _buildComment('Rohit Verma', 'RV', 'Jan 11, 2026', 'Great insights! Digital gifting is indeed the future. I\'ve personally started using Gift360 for all my corporate gifts.'),
            const SizedBox(height: 12),
            _buildComment('Sneha Kapoor', 'SK', 'Jan 10, 2026', 'I love how easy it is to find brands on this platform. This blog post really explains the value of choice well.'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16, color: Colors.grey.shade600), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))],
      ),
    );
  }

  Widget _buildComment(String name, String initials, String date, String comment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0x1A6C5CE7),
            child: Text(initials, style: const TextStyle(color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(comment, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
