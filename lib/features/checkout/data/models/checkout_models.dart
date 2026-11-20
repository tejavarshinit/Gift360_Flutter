class CheckoutEmailRequirement {
  final String mode;
  final bool verified;
  final bool required;
  final bool prompt;
  final String? maskedEmail;
  final String? invalidReason;
  final String? suggestion;

  const CheckoutEmailRequirement({
    required this.mode,
    required this.verified,
    required this.required,
    required this.prompt,
    this.maskedEmail,
    this.invalidReason,
    this.suggestion,
  });

  factory CheckoutEmailRequirement.fromJson(Map<String, dynamic> json) {
    return CheckoutEmailRequirement(
      mode: (json['mode'] ?? 'OFF').toString(),
      verified: json['verified'] == true,
      required: json['required'] == true,
      prompt: json['prompt'] == true,
      maskedEmail: _optionalString(json['maskedEmail']),
      invalidReason: _optionalString(json['invalidReason']),
      suggestion: _optionalString(json['suggestion']),
    );
  }
}

class CheckoutLocationRequirement {
  final String mode;
  final bool ask;
  final bool skipped;
  final bool required;
  final int maxAgeSeconds;
  final bool pinFallback;
  final String notice;

  const CheckoutLocationRequirement({
    required this.mode,
    required this.ask,
    required this.skipped,
    required this.required,
    required this.maxAgeSeconds,
    required this.pinFallback,
    required this.notice,
  });

  factory CheckoutLocationRequirement.fromJson(Map<String, dynamic> json) {
    return CheckoutLocationRequirement(
      mode: (json['mode'] ?? 'OFF').toString(),
      ask: json['ask'] == true,
      skipped: json['skipped'] == true,
      required: json['required'] == true,
      maxAgeSeconds: (json['maxAgeSeconds'] as num?)?.toInt() ?? 300,
      pinFallback: json['pinFallback'] == true,
      notice: (json['notice'] ?? '').toString(),
    );
  }
}

class CheckoutRequirements {
  final CheckoutEmailRequirement? email;
  final CheckoutLocationRequirement? location;

  const CheckoutRequirements({this.email, this.location});

  factory CheckoutRequirements.fromJson(Map<String, dynamic> json) {
    final email = json['email'];
    final location = json['location'];
    return CheckoutRequirements(
      email: email is Map
          ? CheckoutEmailRequirement.fromJson(email.cast<String, dynamic>())
          : null,
      location: location is Map
          ? CheckoutLocationRequirement.fromJson(
              location.cast<String, dynamic>(),
            )
          : null,
    );
  }
}

/// Location consent sent to payment-start endpoints. Coordinates are only
/// included for GPS fixes; PIN submissions never contain coordinates.
class CheckoutLocation {
  final String source;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final int capturedAt;
  final String? pincode;
  final String? city;
  final String? state;
  final bool consent;

  const CheckoutLocation({
    required this.source,
    required this.capturedAt,
    required this.consent,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.pincode,
    this.city,
    this.state,
  });

  factory CheckoutLocation.gps({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required int capturedAt,
    String? pincode,
    String? city,
    String? state,
    bool consent = true,
  }) {
    return CheckoutLocation(
      source: 'GPS',
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      capturedAt: capturedAt,
      pincode: pincode,
      city: city,
      state: state,
      consent: consent,
    );
  }

  factory CheckoutLocation.pin({
    required String pincode,
    required int capturedAt,
    bool consent = true,
  }) {
    return CheckoutLocation(
      source: 'PIN',
      pincode: pincode,
      capturedAt: capturedAt,
      consent: consent,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt,
    if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
    if (city != null && city!.isNotEmpty) 'city': city,
    if (state != null && state!.isNotEmpty) 'state': state,
    'consent': consent,
  };
}

class EmailCheckResult {
  final bool valid;
  final String reason;
  final String? suggestion;
  final bool block;

  const EmailCheckResult({
    required this.valid,
    required this.reason,
    required this.block,
    this.suggestion,
  });

  factory EmailCheckResult.fromJson(Map<String, dynamic> json) {
    return EmailCheckResult(
      valid: json['valid'] == true,
      reason: (json['reason'] ?? '').toString(),
      suggestion: _optionalString(json['suggestion']),
      block: json['block'] == true,
    );
  }
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}
