import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gift360/features/auth/presentation/providers/providers.dart';
import 'package:gift360/features/contact/data/repositories/contact_api.dart';

final contactApiProvider = Provider<ContactApi>((ref) {
  final dio = ref.watch(brandsDioProvider);
  return ContactApi(dio);
});
