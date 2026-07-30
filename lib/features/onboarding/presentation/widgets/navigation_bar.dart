import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';

class OnboardingNavBar extends StatelessWidget {
  final VoidCallback? onSkip;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onStart;
  final bool showSkip;
  final bool showNext;
  final bool showBack;
  final bool showGetStarted;

  const OnboardingNavBar({
    super.key,
    this.onSkip,
    this.onNext,
    this.onBack,
    this.onStart,
    this.showSkip = true,
    this.showNext = true,
    this.showBack = false,
    this.showGetStarted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: onBack,
              child: Text(
                'Back',
                style: OnboardingDesign.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: OnboardingDesign.foreground.withValues(alpha: 0.8),
                ),
              ),
            )
          else if (showSkip)
            GestureDetector(
              onTap: onSkip,
              child: Text(
                'Skip',
                style: OnboardingDesign.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: OnboardingDesign.foreground.withValues(alpha: 0.8),
                ),
              ),
            )
          else
            const SizedBox(),
          if (showGetStarted) ...[
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: onStart,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: OnboardingDesign.primary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: OnboardingDesign.shadowCardSoft,
                  ),
                  child: Center(
                    child: Text(
                      'Get Started',
                      style: OnboardingDesign.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (showNext) ...[
            const Spacer(),
            GestureDetector(
              onTap: onNext,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: OnboardingDesign.primary,
                  shape: BoxShape.circle,
                  boxShadow: OnboardingDesign.shadowCardSoft,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
