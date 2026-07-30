import 'package:flutter/material.dart';
import 'package:gift360/features/onboarding/presentation/widgets/onboarding_design.dart';

class OnboardingStatusBar extends StatelessWidget {
  final bool dark;

  const OnboardingStatusBar({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : OnboardingDesign.foreground;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '9:30',
            style: OnboardingDesign.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Row(
            children: [
              Icon(Icons.signal_cellular_alt, size: 14, color: textColor),
              const SizedBox(width: 4),
              Icon(Icons.wifi, size: 14, color: textColor),
              const SizedBox(width: 4),
              Icon(Icons.battery_full, size: 16, color: textColor),
            ],
          ),
        ],
      ),
    );
  }
}
