import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/navigation/app_navigator.dart';
import 'package:gift360/features/auth/presentation/providers/auth_provider.dart';
import 'package:gift360/features/support/data/repositories/support_ticket_api.dart'
    show TicketClosedException;
import 'package:gift360/features/support/presentation/providers/support_ticket_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// Sahil can end a message with "[[options: A | B | C]]"; shown as tap-to-send chips.
final _optionsRe = RegExp(r'\n?\[\[options:\s*([^\]]*)\]\]\s*$');

({String text, List<String> options}) splitOptions(String message) {
  final m = _optionsRe.firstMatch(message);
  if (m == null) return (text: message, options: const []);
  final text = message.replaceFirst(_optionsRe, '');
  final options = m
      .group(1)!
      .split('|')
      .map((o) => o.trim())
      .where((o) => o.isNotEmpty)
      .toList();
  return (text: text, options: options);
}

// Extract URLs from text for linkification.
List<({bool isUrl, String text})> splitUrls(String text) {
  final urlRe = RegExp(r'(https?://\S+)');
  final parts = <({bool isUrl, String text})>[];
  for (final m in urlRe.allMatches(text)) {
    if (m.start > 0) {
      parts.add((isUrl: false, text: text.substring(0, m.start)));
    }
    parts.add((isUrl: true, text: m.group(0)!));
    text = text.substring(m.end);
  }
  if (text.isNotEmpty) parts.add((isUrl: false, text: text));
  return parts;
}

String _storageKeyFor(dynamic user) {
  final identity = user?.clientId ?? user?.email ?? 'guest';
  return 'gift360_support_ticket_id:$identity';
}

/// Support chat widget matching React's SupportChatWidget.
class SupportChatWidget extends ConsumerStatefulWidget {
  const SupportChatWidget({super.key});

  @override
  ConsumerState<SupportChatWidget> createState() => _SupportChatWidgetState();
}

class _SupportChatWidgetState extends ConsumerState<SupportChatWidget> {
  bool _open = false;
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
      if (mounted && !_open) {
        setState(() => _askLabelVisible = !_askLabelVisible);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: supportChatHideCount,
      builder: (context, hideCount, _) {
        if (hideCount > 0) return const SizedBox.shrink();
        final screen = MediaQuery.sizeOf(context);
        final widgetWidth = math.max(0.0, math.min(320.0, screen.width - 32));
        final panelMaxHeight = screen.height * 0.65;

        // The Stack must occupy the whole panel/FAB area. Previously it sized
        // itself to the 48px FAB, leaving the visually painted chat panel
        // outside the parent's hit-test bounds, so its TextFields could not
        // receive taps or focus.
        return SizedBox(
          width: widgetWidth,
          height: panelMaxHeight + 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_open)
                Positioned(
                  bottom: 60,
                  right: 0,
                  child: _SupportChatPanel(
                    maxWidth: widgetWidth,
                    maxHeight: panelMaxHeight,
                    onClose: () => setState(() => _open = false),
                  ),
                ),
              Positioned(right: 0, bottom: 0, child: _buildFab()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    final isPill = !_open && _askLabelVisible;
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        height: 48,
        // Keep both endpoints finite. Animating AnimatedContainer from a
        // null width (unbounded constraints) to 48px causes BoxConstraints
        // interpolation assertions in Flutter Web.
        width: isPill ? 112 : 48,
        padding: isPill ? const EdgeInsets.only(left: 14, right: 16) : null,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _open
                ? const Icon(Icons.close, color: Colors.white, size: 20)
                : const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 20,
                  ),
            if (isPill) ...[
              const SizedBox(width: 8),
              AnimatedOpacity(
                opacity: _askLabelVisible ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'Ask Us',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chat panel — a fixed overlay positioned above the FAB.
class _SupportChatPanel extends ConsumerStatefulWidget {
  final double maxWidth;
  final double maxHeight;
  final VoidCallback onClose;
  const _SupportChatPanel({
    required this.maxWidth,
    required this.maxHeight,
    required this.onClose,
  });

  @override
  ConsumerState<_SupportChatPanel> createState() => _SupportChatPanelState();
}

class _SupportChatPanelState extends ConsumerState<_SupportChatPanel> {
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
  String? _threadError;

  Timer? _pollTimer;
  DateTime? _waitingSince;
  final Map<int, String> _localVotes = {};
  int? _votingId;

  @override
  void initState() {
    super.initState();
    _prefillFromUser();
    _loadTicketId();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _messageController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _prefillFromUser() {
    final user = ref.read(authProvider);
    if (user != null) {
      if (user.name.isNotEmpty) _nameController.text = user.name;
      if (user.email.isNotEmpty) _emailController.text = user.email;
      if (user.mobile.isNotEmpty) _mobileController.text = user.mobile;
    }
  }

  Future<void> _loadTicketId() async {
    final user = ref.read(authProvider);
    final key = _storageKeyFor(user);
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(key);
    if (saved != null && mounted) {
      setState(() => _ticketId = saved);
      _fetchMessages(saved);
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: _waitingSince != null ? 2 : 10),
      (_) {
        if (_ticketId != null) {
          _fetchMessages(_ticketId!);
        }
      },
    );
  }

  Future<void> _fetchMessages(String id) async {
    try {
      final notifier = ref.read(supportTicketProvider.notifier);
      await notifier.loadThread(id);
      final messages = ref.read(supportTicketProvider).messages;
      final status = ref.read(supportTicketProvider).ticketStatus;

      if (messages.isNotEmpty) {
        final latest = messages.last;
        if (latest.senderType != 'USER') {
          _waitingSince = null;
        }
      }
      if (status == 'CLOSED') {
        _pollTimer?.cancel();
      }
    } catch (e) {
      if (mounted) setState(() => _threadError = e.toString());
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

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      final notifier = ref.read(supportTicketProvider.notifier);
      final success = await notifier.createTicket(
        name: effectiveName,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        mobile: _mobileController.text.trim().isNotEmpty
            ? _mobileController.text.trim()
            : null,
        message: _messageController.text.trim(),
      );
      if (success) {
        final ticketState = ref.read(supportTicketProvider);
        final publicId = ticketState.publicId;
        if (publicId != null) {
          final key = _storageKeyFor(user);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(key, publicId);
          setState(() {
            _ticketId = publicId;
            _waitingSince = DateTime.now();
          });
          _startPolling();
          _fetchMessages(publicId);
        }
      } else {
        final err = ref.read(supportTicketProvider).error;
        setState(
          () => _formError =
              err ?? 'Failed to submit your request. Please try again.',
        );
      }
    } catch (e) {
      setState(() => _formError = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleSendReply([String? override]) async {
    final raw = override ?? _replyController.text;
    if (_ticketId == null || raw.trim().isEmpty) return;
    final text = raw.trim();
    setState(() {
      _sendingReply = true;
      _replyError = null;
    });
    try {
      final notifier = ref.read(supportTicketProvider.notifier);
      final success = await notifier.sendMessage(_ticketId!, text);
      if (success) {
        _replyController.clear();
        setState(() => _waitingSince = DateTime.now());
        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (_ticketId != null) _fetchMessages(_ticketId!);
        });
        _scrollToBottom();
      } else {
        final err = ref.read(supportTicketProvider).error;
        final status = ref.read(supportTicketProvider).ticketStatus;
        if (status == 'CLOSED') {
          setState(() {});
        } else {
          setState(() => _replyError = err ?? 'Failed to send your message.');
        }
      }
    } on TicketClosedException {
      setState(() {});
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _handleVote(int messageId, String vote) async {
    if (_ticketId == null || _votingId != null) return;
    setState(() => _votingId = messageId);
    try {
      final notifier = ref.read(supportTicketProvider.notifier);
      final ok = await notifier.sendFeedback(_ticketId!, messageId, vote);
      if (ok) {
        setState(() => _localVotes[messageId] = vote);
        await _fetchMessages(_ticketId!);
      }
    } catch (e) {
      setState(() => _replyError = e.toString());
    } finally {
      if (mounted) setState(() => _votingId = null);
    }
  }

  Future<void> _handleStartNewChat() async {
    final user = ref.read(authProvider);
    final key = _storageKeyFor(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    _pollTimer?.cancel();
    setState(() {
      _ticketId = null;
      _messageController.clear();
      _replyController.clear();
      _formError = null;
      _replyError = null;
      _threadError = null;
      _waitingSince = null;
      _localVotes.clear();
    });
    ref.read(supportTicketProvider.notifier).reset();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    final local = d.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(supportTicketProvider);
    final user = ref.watch(authProvider);
    final ticketStatus = ticketState.ticketStatus;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: widget.maxWidth,
        constraints: BoxConstraints(
          maxHeight: widget.maxHeight,
          maxWidth: widget.maxWidth,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _ticketId == null
                  ? _buildCreateForm(user)
                  : _buildChatView(ticketState, ticketStatus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'S',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sahil',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF86EFAC),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Your chatbot friend is here',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFBFDBFE),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onClose,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(dynamic user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user == null) ...[
            _buildField('Name *', _nameController, 'Your name'),
            _buildField('Email', _emailController, 'you@example.com'),
            _buildField('Mobile', _mobileController, 'Your mobile number'),
          ],
          _buildField(
            'Message *',
            _messageController,
            "Hi, I'm Sahil! Ask me anything about SuperCoins, vouchers or orders…",
            maxLines: 3,
          ),
          if (_formError != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _formError!,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Start conversation',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView(SupportTicketState ticketState, String? ticketStatus) {
    final messages = ticketState.messages;
    final isClosed = ticketStatus == 'CLOSED';
    final isWaiting = _waitingSince != null && !isClosed;

    // Auto-scroll when messages change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Messages area
        Flexible(
          child: Container(
            color: const Color(0xFFF9FAFB),
            padding: const EdgeInsets.all(12),
            child: ticketState.isLoadingThread && messages.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : messages.isEmpty
                ? Center(
                    child: Text(
                      'Sahil is on it. Your message has been received.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    itemCount: messages.length + (isWaiting ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= messages.length) {
                        return _buildTypingIndicator();
                      }
                      final msg = messages[index];
                      final isLast = index == messages.length - 1;
                      return _buildMessageBubble(
                        msg,
                        isLast,
                        isClosed,
                        ticketStatus,
                      );
                    },
                  ),
          ),
        ),
        // Thread error
        if (_threadError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFFEF2F2),
            child: Text(
              _threadError!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        // Reply error
        if (_replyError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFFEF2F2),
            child: Text(
              _replyError!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        // Footer: closed state or reply input
        if (isClosed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
              color: Color(0xFFF9FAFB),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This conversation is closed.',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: _handleStartNewChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Start New Conversation',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    style: GoogleFonts.poppins(fontSize: 12),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSendReply(),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _sendingReply || _replyController.text.trim().isEmpty
                      ? null
                      : () => _handleSendReply(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _sendingReply
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessageBubble(
    TicketMessage msg,
    bool isLast,
    bool isClosed,
    String? ticketStatus,
  ) {
    final isUser = msg.senderType == 'USER';
    final split = splitOptions(msg.message);
    final senderLabel = msg.senderType == 'BOT'
        ? 'Sahil'
        : msg.senderType == 'ADMIN'
        ? 'Gift360 Support'
        : '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: isUser ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender label
            if (!isUser && senderLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            // Message text with URL linkification
            _buildMessageText(split.text, isUser),
            // Quick-reply options (last non-user message only)
            if (!isUser &&
                isLast &&
                !isClosed &&
                _waitingSince == null &&
                split.options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: split.options
                      .map(
                        (o) => GestureDetector(
                          onTap: _sendingReply
                              ? null
                              : () => _handleSendReply(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            child: Text(
                              o,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            // Thumbs up/down for bot answers
            if (msg.senderType == 'BOT' &&
                msg.id != null &&
                msg.intentKey != null &&
                msg.intentKey!.isNotEmpty)
              _buildVoteRow(msg, isLast, isClosed, ticketStatus),
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatTimestamp(msg.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: isUser ? const Color(0xFFBFDBFE) : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageText(String text, bool isUser) {
    final parts = splitUrls(text);
    return Wrap(
      spacing: 0,
      runSpacing: 2,
      children: parts.map((part) {
        if (part.isUrl) {
          final url = part.text;
          final label = url.contains('/faq/')
              ? 'Read the full answer'
              : url.contains('/brands/')
              ? 'Buy now'
              : url;
          return GestureDetector(
            onTap: () async {
              // Brand links open the buy sheet; FAQ opens in browser.
              if (url.contains('/brands/')) {
                // TODO: open PaymentDetailsSheet with brand ID
                final brandMatch = RegExp(
                  r'/brands/([^/\s?#]+)',
                ).firstMatch(url);
                if (brandMatch != null && mounted) {
                  // Navigate to brand page
                  // For now, launch externally
                }
              }
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: isUser ? Colors.white : const Color(0xFF2563EB),
                decoration: TextDecoration.underline,
                decorationColor: isUser
                    ? Colors.white
                    : const Color(0xFF2563EB),
              ),
            ),
          );
        }
        return Text(
          part.text,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isUser ? Colors.white : const Color(0xFF1F2937),
            height: 1.4,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVoteRow(
    TicketMessage msg,
    bool isLast,
    bool isClosed,
    String? ticketStatus,
  ) {
    final mid = msg.id!;
    final vote = _localVotes[mid] ?? msg.vote;
    final active =
        isLast && !isClosed && _waitingSince == null && _votingId == null;

    Widget voteBtn(String v, IconData icon) {
      final selected = vote == v;
      return GestureDetector(
        onTap: active ? () => _handleVote(mid, v) : null,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFEFF6FF) : Colors.white,
            border: Border.all(
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Icon(
            icon,
            size: 12,
            color: selected ? const Color(0xFF2563EB) : Colors.grey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Was this helpful?',
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          voteBtn('UP', Icons.thumb_up_alt_outlined),
          const SizedBox(width: 4),
          voteBtn('DOWN', Icons.thumb_down_alt_outlined),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            16,
          ).copyWith(bottomLeft: const Radius.circular(4)),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sahil',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2563EB),
              ),
            ),
            Text(
              ' is typing',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 4),
            ...List.generate(3, (i) {
              return _TypingDot(delayMs: i * 150);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: maxLines > 1 ? maxLines : null,
            style: GoogleFonts.poppins(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single bouncing dot for the typing indicator.
class _TypingDot extends StatefulWidget {
  final int delayMs;
  const _TypingDot({this.delayMs = 0});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.repeat();
      });
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final dy = -4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
