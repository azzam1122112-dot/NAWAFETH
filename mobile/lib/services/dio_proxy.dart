import 'package:dio/dio.dart';

import 'dio_proxy_stub.dart' if (dart.library.io) 'dio_proxy_io.dart' as impl;

/// Configures Dio for local development (e.g. bypass system proxy for localhost).
void configureDioForLocalhost(Dio dio, String baseUrl) {
  // Delegates to platform-specific implementation.
  impl.configureDioForLocalhostImpl(dio, baseUrl);
}
