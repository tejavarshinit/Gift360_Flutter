import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/support/presentation/providers/support_ticket_provider.dart';

class SupportTicketWidget extends ConsumerStatefulWidget {
  const SupportTicketWidget({super.key});

  @override
  ConsumerState<SupportTicketWidget> createState() => _SupportTicketWidgetState();
}

class _SupportTicketWidgetState extends ConsumerState<SupportTicketWidget> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(supportTicketProvider);
    final user = ref.watch(authProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Support', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (ticketState.publicId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: ticketState.ticketStatus == 'OPEN'
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ticketState.ticketStatus ?? 'OPEN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: ticketState.ticketStatus == 'OPEN'
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Messages
              Expanded(
                child: ticketState.publicId == null
                    ? _buildCreateTicketForm(user, ticketState)
                    : _buildMessageThread(ticketState),
              ),
              // Input
              if (ticketState.publicId != null && ticketState.ticketStatus != 'CLOSED')
                _buildMessageInput(ticketState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateTicketForm(dynamic user, SupportTicketState ticketState) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final messageController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create a support ticket', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: messageController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                labelText: 'Describe your issue',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: ticketState.isCreating
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final message = messageController.text.trim();
                      if (name.isEmpty || message.isEmpty) return;

                      final success = await ref.read(supportTicketProvider.notifier).createTicket(
                            name: name,
                            email: user?.email,
                            mobile: user?.mobile,
                            message: message,
                          );

                      if (success && mounted) {
                        // Load the thread
                        final publicId = ref.read(supportTicketProvider).publicId;
                        if (publicId != null) {
                          ref.read(supportTicketProvider.notifier).loadThread(publicId);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
              ),
              child: ticketState.isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageThread(SupportTicketState ticketState) {
    if (ticketState.isLoadingThread) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = ticketState.messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isUser = msg.senderType == 'USER';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF6C5CE7) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUser ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  msg.createdAt,
                  style: TextStyle(
                    fontSize: 10,
                    color: isUser ? Colors.white70 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(SupportTicketState ticketState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: ticketState.isSending
                ? null
                : () async {
                    final message = _messageController.text.trim();
                    if (message.isEmpty) return;
                    _messageController.clear();

                    final publicId = ticketState.publicId;
                    if (publicId == null) return;

                    await ref.read(supportTicketProvider.notifier).sendMessage(publicId, message);
                    _scrollToBottom();
                  },
            icon: ticketState.isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send, color: Color(0xFF6C5CE7)),
          ),
        ],
      ),
    );
  }
}
