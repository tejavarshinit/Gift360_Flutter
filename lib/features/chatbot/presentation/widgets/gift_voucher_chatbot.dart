import 'package:flutter/material.dart';

class ChatMessage {
  final String id;
  final bool isUser;
  final String content;
  final DateTime timestamp;
  final List<String>? suggestedActions;

  ChatMessage({required this.id, required this.isUser, required this.content, DateTime? timestamp, this.suggestedActions})
      : timestamp = timestamp ?? DateTime.now();
}

class GiftVoucherChatbot extends StatefulWidget {
  const GiftVoucherChatbot({super.key});

  @override
  State<GiftVoucherChatbot> createState() => _GiftVoucherChatbotState();
}

class _GiftVoucherChatbotState extends State<GiftVoucherChatbot> {
  bool _isOpen = false;
  bool _isMinimized = false;
  final List<ChatMessage> _messages = [];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      id: 'welcome',
      isUser: false,
      content: '👋 **Welcome to Gift360 Support!**\n\nI\'m here to help you with everything related to gift vouchers!\n\n🎁 **I can help you with:**\n• Redeeming gift vouchers\n• Checking balance & validity\n• Brand information & availability\n• Corporate bulk orders\n• Troubleshooting issues\n\nAsk me anything!',
      suggestedActions: ['What brands are available?', 'How to redeem vouchers?', 'Check balance', 'Corporate orders'],
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), isUser: true, content: text.trim());
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 800));

    final response = _getResponse(text);
    final botMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: false,
      content: response['content'] as String,
      suggestedActions: (response['actions'] as List).cast<String>(),
    );

    setState(() {
      _messages.add(botMsg);
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Map<String, dynamic> _getResponse(String query) {
    final q = query.toLowerCase();

    if (q.contains('brand') || q.contains('available') || (q.contains('which') && (q.contains('voucher') || q.contains('card')))) {
      return {
        'content': '**Available Brands on Gift360:**\n\nWe offer gift vouchers for **500+ brands** across multiple categories:\n\n🛒 **E-Commerce:**\n• Amazon, Flipkart, Myntra, Ajio, Nykaa\n\n👔 **Fashion & Lifestyle:**\n• Lifestyle, Pantaloons, Westside, Max Fashion, Shoppers Stop\n\n🍕 **Food & Dining:**\n• Dominos, Swiggy, Zomato, Cafe Coffee Day, Barbeque Nation, KFC, McDonald\'s\n\n📱 **Electronics:**\n• Croma, Reliance Digital, Vijay Sales\n\n🎬 **Entertainment:**\n• BookMyShow, PVR Cinemas, INOX\n\n✈️ **Travel:**\n• MakeMyTrip, Cleartrip, Yatra, OYO\n\nAnd many more!',
        'actions': ['Amazon vouchers', 'Flipkart details', 'Fashion brands', 'Corporate orders']
      };
    }

    if (q.contains('redeem') || q.contains('use') || q.contains('how to')) {
      return {
        'content': '**How to Redeem Your Gift Voucher:**\n\n📱 **Online Redemption:**\n1. Visit the brand\'s website or app\n2. Shop and add products to cart\n3. Go to checkout/payment page\n4. Select "Gift Card/Voucher" as payment method\n5. Enter your 16-digit card number and PIN\n6. Apply and complete your purchase\n\n🏪 **In-Store Redemption:**\n1. Visit any brand store\n2. Shop for products\n3. At checkout, present your gift card\n4. Provide mobile number for verification\n5. Card will be swiped/scanned\n\n💡 **Pro Tips:**\n• You can use the card multiple times until balance is zero\n• Check balance before shopping\n• Keep PIN secure\n• Take screenshot of digital cards',
        'actions': ['Check balance', 'Redemption failed?', 'Find stores', 'Available brands']
      };
    }

    if (q.contains('balance') || q.contains('check')) {
      return {
        'content': '**Check Your Voucher Balance:**\n\n**Method 1: SabbPe App/Website**\n• Log in to your account\n• Go to "My Vouchers" section\n• Select your voucher\n• Balance displayed in real-time\n\n**Method 2: Brand Website**\n• Visit brand\'s official website\n• Look for "Check Gift Card Balance"\n• Enter card number and PIN\n\n**Method 3: During Purchase**\n• Your balance shows at checkout\n• When you apply the gift card\n\n⏱️ Balance Update Time: After redemption, balance typically updates within 2-3 hours.',
        'actions': ['Redeem voucher', 'Balance not updated?', 'Purchase more', 'Available brands']
      };
    }

    if (q.contains('corporate') || q.contains('bulk') || q.contains('business') || q.contains('b2b') || q.contains('company')) {
      return {
        'content': '**Corporate Gift Voucher Solutions:**\n\n**What We Offer:**\n🎁 Bulk gift vouchers with volume discounts\n🏷️ Custom branding with your company logo\n📦 Flexible denomination options\n💼 Employee rewards & recognition programs\n🤝 Channel partner incentives\n🎊 Festival & occasion gifting\n\n**Process:**\n1. Contact B2B Team:\n   📧 B2B@gift360.io\n   📞 +91-8765432109\n\n2. Share Requirements:\n   • Brands needed\n   • Quantity & Denominations\n   • Custom branding needs\n\n3. Get Quote → Approval → Delivery\n\n**Benefits:**\n✓ Dedicated account manager\n✓ Flexible payment terms\n✓ GST invoicing\n✓ Recipient tracking\n✓ Post-delivery support',
        'actions': ['Get quote', 'Custom branding', 'Available brands', 'Payment terms']
      };
    }

    if (q.contains('issue') || q.contains('problem') || q.contains('not working') || q.contains('error') || q.contains('failed')) {
      return {
        'content': '**Troubleshooting Common Issues:**\n\n❌ **Redemption Failed:**\n• Verify card number (16 digits, no spaces)\n• Check PIN is correct\n• Ensure card hasn\'t expired\n• Check if you have sufficient balance\n• Try different browser/device\n\n❌ **Card Not Received:**\n• Check spam/junk folder\n• Wait 5-10 minutes for email delivery\n• Verify email address entered correctly\n• Check order status in SabbPe account\n\n❌ **Balance Not Updated:**\n• Wait 2-3 hours after redemption\n• Check on brand\'s website directly\n• Verify transaction was successful\n\n❌ **Payment Failed During Purchase:**\n• Check bank/card limits\n• Verify OTP correctly\n• Try different payment method\n\nStill Having Issues? Create a support ticket!',
        'actions': ['Create support ticket', 'Check balance', 'Contact support', 'Try redemption again']
      };
    }

    if (q.contains('refund') || q.contains('cancel') || q.contains('return')) {
      return {
        'content': '**Refund & Cancellation Policy:**\n\n✅ **Eligible for Cancellation:**\n• Cancel within 24 hours of purchase\n• Card must not be accessed/used\n• Full refund processed\n\n❌ **NOT Eligible for Refund:**\n• Used/activated cards (even partially)\n• Cards accessed or PIN revealed\n• After 24 hours (digital) or 48 hours (physical)\n• Expired cards\n\n🔄 **Refund Process:**\n1. Email: support@gift360.io\n2. Provide order ID and reason\n3. Our team reviews within 24 hours\n4. Refund processed in 5-7 business days',
        'actions': ['Create support ticket', 'Exchange policy', 'Purchase new', 'Contact support']
      };
    }

    if (q.contains('payment') || q.contains('pay') || q.contains('how to buy')) {
      return {
        'content': '**Payment Methods & Purchase Process:**\n\n**Accepted Payment Methods:**\n💳 Credit/Debit Cards (Visa, Mastercard, RuPay)\n📱 UPI (Google Pay, PhonePe, Paytm)\n🏦 Net Banking (All major banks)\n💰 Wallets (Paytm, Mobikwik)\n💼 Corporate: Bank transfer, Cheque, Credit terms\n\n**How to Purchase:**\n1. Visit Gift360 website/app\n2. Browse brands\n3. Select denomination\n4. Add to cart\n5. Enter details & choose payment\n6. Complete payment securely\n7. Receive voucher instantly!\n\n🔒 **Security:**\n✓ 256-bit SSL encryption\n✓ PCI DSS compliant\n✓ No card details stored',
        'actions': ['Purchase now', 'Corporate orders', 'Available brands', 'Security info']
      };
    }

    // Default
    return {
      'content': 'I\'d be happy to help you with that!\n\nBased on your question, here are some topics I can assist you with:\n\n**Popular Topics:**\n• **Available Brands** - 500+ brands including Amazon, Flipkart, fashion, food & more\n• **How to Redeem** - Step-by-step redemption guide\n• **Check Balance** - Multiple ways to check your voucher balance\n• **Corporate Orders** - Bulk purchases with custom branding\n• **Troubleshooting** - Help with common issues\n\nCould you please clarify what you\'d like to know?',
      'actions': ['Available brands', 'How to redeem?', 'Check balance', 'Corporate orders']
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      return Positioned(
        bottom: 80,
        right: 16,
        child: GestureDetector(
          onTap: () => setState(() => _isOpen = true),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.chat_bubble, color: Colors.white, size: 22),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 80,
      right: 16,
      child: Material(
        elevation: 20,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: _isMinimized ? 200 : 300,
          height: _isMinimized ? 48 : 450,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gift360 Assistant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Row(
                            children: [
                              CircleAvatar(radius: 3, backgroundColor: Colors.greenAccent),
                              SizedBox(width: 4),
                              Text('Online', style: TextStyle(color: Colors.white70, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isMinimized ? Icons.maximize : Icons.minimize, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _isMinimized = !_isMinimized),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _isOpen = false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              if (!_isMinimized) ...[
                // Messages
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),

                // Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                          onPressed: () => _sendMessage(_inputController.text),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!msg.isUser)
            const CircleAvatar(
              radius: 12,
              backgroundColor: Color(0xFF2563EB),
              child: Icon(Icons.smart_toy, color: Colors.white, size: 14),
            ),
          if (!msg.isUser) const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: msg.isUser ? const Color(0xFF2563EB) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12).copyWith(
                      bottomRight: msg.isUser ? const Radius.circular(2) : null,
                      bottomLeft: !msg.isUser ? const Radius.circular(2) : null,
                    ),
                  ),
                  child: Text(
                    msg.content.replaceAll('**', ''),
                    style: TextStyle(fontSize: 12, color: msg.isUser ? Colors.white : Colors.black87, height: 1.5),
                  ),
                ),
                if (msg.suggestedActions != null && msg.suggestedActions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: msg.suggestedActions!.map((action) {
                        return GestureDetector(
                          onTap: () => _sendMessage(action),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(action, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          if (msg.isUser) const SizedBox(width: 6),
          if (msg.isUser)
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
              child: const Icon(Icons.person, color: Color(0xFF2563EB), size: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 12,
            backgroundColor: Color(0xFF2563EB),
            child: Icon(Icons.smart_toy, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(150),
                const SizedBox(width: 4),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: value > 0.5 ? 1 - (value - 0.5) * 2 : value * 2,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
