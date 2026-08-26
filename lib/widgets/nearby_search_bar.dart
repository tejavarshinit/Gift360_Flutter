import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NearbySearchBar extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const NearbySearchBar({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD8D8FF), Color(0xFFB9C7FF), Color(0xFFE7D7FF)],
          ),
          boxShadow: const [BoxShadow(color: Color(0x144954B1), blurRadius: 30, offset: Offset(0, 10))],
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          height: 48,
          decoration: BoxDecoration(color: const Color(0xFFF9F9FD), borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              const Padding(padding: EdgeInsets.only(left: 16), child: Icon(Icons.search, color: Color(0xFF7F8699), size: 16)),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: value),
                  onChanged: onChanged,
                  style: AppTextStyles.searchText,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search nearby brands...',
                    hintStyle: AppTextStyles.searchPlaceholder,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
