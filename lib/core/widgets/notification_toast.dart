import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gift360/core/providers/notification_provider.dart';
import 'package:gift360/features/notifications/data/models/app_notification.dart';

class NotificationToast extends ConsumerStatefulWidget {
  const NotificationToast({super.key});

  @override
  ConsumerState<NotificationToast> createState() => _NotificationToastState();
}

class _NotificationToastState extends ConsumerState<NotificationToast> {
  AppNotification? _currentToast;
  bool _isVisible = false;
  int _lastCount = 0;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationProvider);

    // Detect new notification
    if (notifications.length > _lastCount && notifications.isNotEmpty) {
      _lastCount = notifications.length;
      _showToast(notifications.first);
    } else if (notifications.isEmpty) {
      _lastCount = 0;
    }

    if (!_isVisible || _currentToast == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 16,
      right: 16,
      child: AnimatedSlide(
        offset: _isVisible ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 342),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      _currentToast!.type == 'success'
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 18,
                      color: _currentToast!.type == 'success'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF67657C),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentToast!.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3E3E3E),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isVisible = false;
                        _currentToast = null;
                      }),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF67657C)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentToast!.message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF67657C),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showToast(AppNotification notification) {
    setState(() {
      _currentToast = notification;
      _isVisible = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isVisible = false);
      }
    });
    Future.delayed(const Duration(seconds: 3, milliseconds: 400), () {
      if (mounted) {
        setState(() => _currentToast = null);
      }
    });
  }
}
