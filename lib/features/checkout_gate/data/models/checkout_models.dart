// Checkout gate models — mirrors React `checkoutApi.ts`.

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

  factory CheckoutEmailRequirement.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return CheckoutEmailRequirement(
      mode: json['mode']?.toString() ?? 'SOFT',
      verified: json['verified'] == true,
      required: json['required'] == true,
      prompt: json['prompt'] == true,
      maskedEmail: json['maskedEmail']?.toString(),
      invalidReason: json['invalidReason']?.toString(),
      suggestion: json['suggestion']?.toString(),
    );
  }

  bool get shouldAsk => prompt && !verified;
}

class CheckoutLocationRequirement {
  final String mode;
  final bool ask;
  final bool skipped;
  final bool required;
  final int maxAgeSeconds;
  final bool pinFallback;
  final String? notice;

  const CheckoutLocationRequirement({
    required this.mode,
    required this.ask,
    required this.skipped,
    required this.required,
    required this.maxAgeSeconds,
    required this.pinFallback,
    this.notice,
  });

  factory CheckoutLocationRequirement.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return CheckoutLocationRequirement(
      mode: json['mode']?.toString() ?? 'COLLECT',
      ask: json['ask'] == true,
      skipped: json['skipped'] == true,
      required: json['required'] == true,
      maxAgeSeconds: (json['maxAgeSeconds'] as num?)?.toInt() ?? 300,
      pinFallback: json['pinFallback'] != false,
      notice: json['notice']?.toString(),
    );
  }
}

class CheckoutRequirements {
  final CheckoutEmailRequirement email;
  final CheckoutLocationRequirement location;

  const CheckoutRequirements({required this.email, required this.location});

  factory CheckoutRequirements.fromJson(Map<String, dynamic> json) {
    return CheckoutRequirements(
      email: CheckoutEmailRequirement.fromJson(
        json['email'] is Map
            ? Map<String, dynamic>.from(json['email'] as Map)
            : null,
      ),
      location: CheckoutLocationRequirement.fromJson(
        json['location'] is Map
            ? Map<String, dynamic>.from(json['location'] as Map)
            : null,
      ),
    );
  }

  bool get needsDialog => email.shouldAsk || location.ask;
}

class EmailCheckResult {
  final bool ok;
  final bool block;
  final String? suggestion;
  final String? message;
  final String? invalidReason;

  const EmailCheckResult({
    required this.ok,
    required this.block,
    this.suggestion,
    this.message,
    this.invalidReason,
  });

  factory EmailCheckResult.fromJson(Map<String, dynamic> json) {
    return EmailCheckResult(
      ok: json['ok'] == true || json['valid'] == true,
      block: json['block'] == true,
      suggestion: json['suggestion']?.toString(),
      message: json['message']?.toString(),
      invalidReason: json['invalidReason']?.toString() ??
          json['reason']?.toString(),
    );
  }
}

/// Location payload attached to initiate/retry/UPI payment calls.
class CheckoutLocation {
  final String source; // GPS | PIN
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

  Map<String, dynamic> toJson() => {
        'source': source,
        'capturedAt': capturedAt,
        'consent': consent,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (pincode != null && pincode!.isNotEmpty) 'pincode': pincode,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (state != null && state!.isNotEmpty) 'state': state,
      };
}

enum CheckoutGateOutcome { proceeded, cancelled }

class CheckoutGateResult {
  final CheckoutGateOutcome outcome;
  final CheckoutLocation? location;

  const CheckoutGateResult._(this.outcome, this.location);

  factory CheckoutGateResult.proceeded([CheckoutLocation? location]) =>
      CheckoutGateResult._(CheckoutGateOutcome.proceeded, location);

  factory CheckoutGateResult.cancelled() =>
      const CheckoutGateResult._(CheckoutGateOutcome.cancelled, null);

  bool get isCancelled => outcome == CheckoutGateOutcome.cancelled;
}
