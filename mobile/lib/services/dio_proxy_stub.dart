import 'package:dio/dio.dart';

/// No-op implementation for platforms without `dart:io` (e.g. web).
void configureDioForLocalhostImpl(Dio dio, String baseUrl) {
  // Intentionally empty.
}
