import 'package:flutter/material.dart';

class PaymentFlowSheet extends StatefulWidget {
  final bool isOpen;
  final String state; // 'loading' or 'success'
  final VoidCallback? onViewVoucherClick;

  const PaymentFlowSheet({
    super.key,
    required this.isOpen,
    required this.state,
    this.onViewVoucherClick,
  });

  @override
  State<PaymentFlowSheet> createState() => _PaymentFlowSheetState();
}

class _PaymentFlowSheetState extends State<PaymentFlowSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    if (widget.isOpen) _controller.forward();
  }

  @override
  void didUpdateWidget(PaymentFlowSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _controller.forward(from: 0);
    } else if (!widget.isOpen && oldWidget.isOpen) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final isSuccess = widget.state == 'success';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  color: const Color(0x57181827).withValues(alpha: 0.34),
                ),
              ),
            ),
            // Panel
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  margin: const EdgeInsets.symmetric(horizontal: 0),
                  decoration: BoxDecoration(
                    gradient: isSuccess
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFE8D5F5), Colors.white],
                          ),
                    color: isSuccess ? Colors.white : null,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x2821184A),
                        blurRadius: 48,
                        offset: const Offset(0, -16),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle
                      Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6D5AE6).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 22),

                      if (!isSuccess) ...[
                        // Loading state
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.18),
                              width: 6,
                            ),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Processing your payment...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF403A64),
                          ),
                        ),
                      ] else ...[
                        // Success state
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFFC7F5D8), Color(0xFF7DDB99)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7DDB99).withValues(alpha: 0.35),
                                blurRadius: 36,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFF41B66E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Voucher Purchased Successfully',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A2E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: widget.onViewVoucherClick,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View Voucher',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6C5CE7),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 16, color: Color(0xFF6C5CE7)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
