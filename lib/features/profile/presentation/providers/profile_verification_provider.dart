import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/profile/data/models/profile_verification.dart';
import 'package:gift360/features/profile/data/repositories/profile_verification_api.dart';

final profileVerificationApiProvider = Provider<ProfileVerificationApi>((ref) {
  return ProfileVerificationApi(ref.watch(brandsDioProvider));
});

/// One fetch per profile-screen lifetime, keyed on the logged-in client id.
final profileVerificationProvider = FutureProvider.autoDispose
    .family<ProfileVerification, String>((ref, clientId) {
      if (clientId.trim().isEmpty) {
        throw StateError('profile verification needs a client id');
      }
      return ref.watch(profileVerificationApiProvider).fetch();
    });

/// Failure is neutral: the profile screen renders no badge and never blocks.
ProfileVerification? profileVerificationOrNull(
  AsyncValue<ProfileVerification> value,
) => value.valueOrNull;
