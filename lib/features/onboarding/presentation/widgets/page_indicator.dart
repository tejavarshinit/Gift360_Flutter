import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';

class PageIndicator extends StatelessWidget {
  final int pageCount;
  final int activeIndex;

  const PageIndicator({
    super.key,
    required this.pageCount,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (i) {
        final isActive = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? OnboardingDesign.primary
                : OnboardingDesign.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
