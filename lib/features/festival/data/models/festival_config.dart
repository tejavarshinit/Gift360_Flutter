import 'package:flutter/material.dart';

/// Remote-ready festival theme. Backend can later return the same JSON shape;
/// until then [FestivalConfig.defaults] keeps today's Diwali look.
class FestivalConfig {
  const FestivalConfig({
    required this.id,
    required this.enabled,
    required this.name,
    required this.badgeLabel,
    required this.headline,
    required this.subheadline,
    required this.tagline,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.logoUrl,
    required this.loginBackgroundUrl,
    required this.heroImageUrl,
    this.startAt,
    this.endAt,
  });

  final String id;
  final bool enabled;
  final String name;
  final String badgeLabel;
  final String headline;
  final String subheadline;
  final String tagline;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  /// Asset path (`assets/...`) or https URL.
  final String logoUrl;
  final String loginBackgroundUrl;
  final String heroImageUrl;

  final DateTime? startAt;
  final DateTime? endAt;

  bool get isActive {
    if (!enabled) return false;
    final now = DateTime.now().toUtc();
    if (startAt != null && now.isBefore(startAt!.toUtc())) return false;
    if (endAt != null && now.isAfter(endAt!.toUtc())) return false;
    return true;
  }

  /// Current shipped Diwali experience (assets + colors already in the app).
  static FestivalConfig get defaults => const FestivalConfig(
        id: 'diwali',
        enabled: true,
        name: 'Diwali',
        badgeLabel: '🪔 HAPPY\nDIWALI',
        headline: 'GUARANTEED SAVINGS',
        subheadline: 'On Your Daily Purchases',
        tagline: 'Upto 20% cashback + SuperCoins on 400+ brands',
        primaryColor: Color(0xFFD4650F),
        secondaryColor: Color(0xFFB5246F),
        accentColor: Color(0xFF3F1A55),
        logoUrl: 'assets/images/gift360full.png',
        loginBackgroundUrl: 'assets/images/LoginBackground.png',
        heroImageUrl: 'assets/images/diwali-gift.png',
      );

  /// Neutral fallback when festival is off — still looks polished.
  static FestivalConfig get inactive => const FestivalConfig(
        id: 'default',
        enabled: false,
        name: '',
        badgeLabel: '',
        headline: 'GUARANTEED SAVINGS',
        subheadline: 'On Your Daily Purchases',
        tagline: 'Upto 20% cashback + SuperCoins on 400+ brands',
        primaryColor: Color(0xFF6C5CE7),
        secondaryColor: Color(0xFF8B5CF6),
        accentColor: Color(0xFF1F1635),
        logoUrl: 'assets/images/gift360full.png',
        loginBackgroundUrl: 'assets/images/LoginBackground.png',
        heroImageUrl: 'assets/images/diwali-gift.png',
      );

  factory FestivalConfig.fromJson(Map<String, dynamic> json) {
    Color parseColor(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      var value = hex.trim();
      if (value.startsWith('#')) value = value.substring(1);
      if (value.length == 6) value = 'FF$value';
      final parsed = int.tryParse(value, radix: 16);
      return parsed == null ? fallback : Color(parsed);
    }

    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    final d = defaults;
    return FestivalConfig(
      id: (json['id'] ?? json['festivalId'] ?? d.id).toString(),
      enabled: json['enabled'] != false,
      name: (json['name'] ?? d.name).toString(),
      badgeLabel: (json['badgeLabel'] ?? json['badge'] ?? d.badgeLabel)
          .toString(),
      headline: (json['headline'] ?? d.headline).toString(),
      subheadline: (json['subheadline'] ?? d.subheadline).toString(),
      tagline: (json['tagline'] ?? d.tagline).toString(),
      primaryColor: parseColor(
        (json['primaryColor'] ?? json['theme']?['primaryColor'])?.toString(),
        d.primaryColor,
      ),
      secondaryColor: parseColor(
        (json['secondaryColor'] ?? json['theme']?['secondaryColor'])
            ?.toString(),
        d.secondaryColor,
      ),
      accentColor: parseColor(
        (json['accentColor'] ?? json['theme']?['accentColor'])?.toString(),
        d.accentColor,
      ),
      logoUrl: (json['logoUrl'] ??
              json['theme']?['logoUrl'] ??
              d.logoUrl)
          .toString(),
      loginBackgroundUrl: (json['loginBackgroundUrl'] ??
              json['theme']?['loginBackgroundUrl'] ??
              d.loginBackgroundUrl)
          .toString(),
      heroImageUrl: (json['heroImageUrl'] ??
              json['theme']?['heroImageUrl'] ??
              d.heroImageUrl)
          .toString(),
      startAt: parseDate(json['startAt']),
      endAt: parseDate(json['endAt']),
    );
  }

  FestivalConfig get effective => isActive ? this : inactive;
}
