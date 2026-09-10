import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/support/presentation/providers/support_ticket_provider.dart';
import 'package:gift360/features/support/data/repositories/support_ticket_api.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Support chat widget matching React's SupportChatWidget.
/// Floating button at bottom-right, opens a dialog for the chat panel.
class SupportChatWidget extends ConsumerStatefulWidget {
  const SupportChatWidget({super.key});

  @override
  ConsumerState<SupportChatWidget> createState() => _SupportChatWidgetState();
}

class _SupportChatWidgetState extends ConsumerState<SupportChatWidget> {
  bool _askLabelVisible = true;
  Timer? _askLabelTimer;

  @override
  void initState() {
    super.initState();
    _startAskLabelTimer();
  }

  @override
  void dispose() {
    _askLabelTimer?.cancel();
    super.dispose();
  }

  void _startAskLabelTimer() {
    _askLabelTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (mounted) {
        setState(() => _askLabelVisible = !_askLabelVisible);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openChatDialog(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _askLabelVisible ? null : 48,
        height: 48,
        padding: _askLabelVisible ? const EdgeInsets.symmetric(horizontal: 14) : null,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent, color: Colors.white, size: 20),
            if (_askLabelVisible) ...[
              const SizedBox(width: 6),
              Text('Ask Us!!', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }

  void _openChatDialog() {
    showDialog(
      context: context,
      builder: (_) => const _SupportChatDialog(),
    );
  }
}

/// The actual chat dialog — separated so it manages its own state.
class _SupportChatDialog extends ConsumerStatefulWidget {
  const _SupportChatDialog();

  @override
  ConsumerState<_SupportChatDialog> createState() => _SupportChatDialogState();
}

class _SupportChatDialogState extends ConsumerState<_SupportChatDialog> {
  String? _ticketId;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _messageController = TextEditingController();
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

  bool _submitting = false;
  String? _formError;
  bool _sendingReply = false;
  String? _replyError;

  @override
  void initState() {
    super.initState();
    _loadTicketId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _messageController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _storageKey(dynamic user) {
    final identity = user?.clientId ?? user?.email ?? 'guest';
    return 'gift360_support_ticket_id:$identity';
  }

  Future<void> _loadTicketId() async {
    final user = ref.read(authProvider);
    final key = _storageKey(user);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(key);
    if (saved != null && mounted) {
      setState(() => _ticketId = saved);
      ref.read(supportTicketProvider.notifier).loadThread(saved);
    }
  }

  Future<void> _handleSubmit() async {
    final user = ref.read(authProvider);
    final effectiveName = user != null
        ? (_nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : user.name.isNotEmpty
                ? user.name
                : user.mobile.isNotEmpty
                    ? user.mobile
                    : 'Gift360 User')
        : _nameController.text.trim();

    if (effectiveName.isEmpty || _messageController.text.trim().isEmpty) {
      setState(() => _formError = 'Please enter your name and a message.');
      return;
    }

    setState(() { _submitting = true; _formError = null; });

    try {
      final notifier = ref.read(supportTicketProvider.notifier);
      final success = await notifier.createTicket(
        name: effectiveName,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : user?.email,
        mobile: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : user?.mobile,
        message: _messageController.text.trim(),
      );
      if (success) {
        final ticketState = ref.read(supportTicketProvider);
        final publicId = ticketState.publicId;
        if (publicId != null) {
          final key = _storageKey(user);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(key, publicId);
          setState(() => _ticketId = publicId);
          ref.read(supportTicketProvider.notifier).loadThread(publicId);
        }
      }
    } catch (e) {
      setState(() => _formError = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _handleSendReply() async {
    if (_ticketId == null || _replyController.text.trim().isEmpty) return;
    final text = _replyController.text.trim();
    setState(() { _sendingReply = true; _replyError = null; });
    try {
      final notifier = ref.read(supportTicketProvider.notifier);
      final success = await notifier.sendMessage(_ticketId!, text);
      if (success) {
        _replyController.clear();
        _scrollToBottom();
      }
    } catch (e) {
      if (e is TicketClosedError) {
        setState(() => _replyError = 'This conversation is closed.');
      } else {
        setState(() => _replyError = e.toString());
      }
    } finally {
      setState(() => _sendingReply = false);
    }
  }

  void _handleStartNewChat() async {
    final user = ref.read(authProvider);
    final key = _storageKey(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    setState(() { _ticketId = null; _messageController.clear(); _replyController.clear(); _formError = null; _replyError = null; });
    ref.read(supportTicketProvider.notifier).reset();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(supportTicketProvider);
    final user = ref.watch(authProvider);
    final ticketStatus = ticketState.ticketStatus;
    final messages = ticketState.messages;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 340,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Support Chat', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('We usually reply within a few hours', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: _ticketId == null
                  ? _buildCreateForm(user)
                  : _buildChatView(ticketState, ticketStatus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateForm(dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user == null) ...[
            _buildField('Name *', _nameController, 'Your name'),
            _buildField('Email', _emailController, 'you@example.com'),
            _buildField('Mobile', _mobileController, 'Your mobile number'),
          ],
          _buildField('Message *', _messageController, 'How can we help you?', maxLines: 3),
          if (_formError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(_formError!, style: GoogleFonts.poppins(fontSize: 11, color: Colors.red)),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Start conversation', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(SupportTicketState ticketState, String? ticketStatus) {
    final messages = ticketState.messages;
    return Column(
      children: [
        Expanded(
          child: ticketState.isLoadingThread && messages.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : messages.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Your message has been received. Our support team will respond here shortly.',
                          textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    ))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isUser = msg.senderType == 'USER';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            constraints: const BoxConstraints(maxWidth: 260),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isUser ? const Color(0xFF2563EB) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12).copyWith(
                                bottomRight: isUser ? const Radius.circular(4) : null,
                                bottomLeft: !isUser ? const Radius.circular(4) : null,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(msg.message, style: GoogleFonts.poppins(fontSize: 12, color: isUser ? Colors.white : Colors.black87)),
                                const SizedBox(height: 2),
                                Text(msg.createdAt, style: GoogleFonts.poppins(fontSize: 8, color: isUser ? Colors.white60 : Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (ticketState.error != null || _replyError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.red.shade50,
            child: Text(ticketState.error ?? _replyError!, style: GoogleFonts.poppins(fontSize: 10, color: Colors.red)),
          ),
        if (ticketStatus == 'CLOSED')
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('This conversation is closed.', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleStartNewChat,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                    child: Text('Start New Conversation', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    maxLines: null,
                    style: GoogleFonts.poppins(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSendReply(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sendingReply || _replyController.text.trim().isEmpty ? null : _handleSendReply,
                  icon: _sendingReply
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, size: 18, color: Color(0xFF2563EB)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.poppins(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
