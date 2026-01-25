import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void configureDioForLocalhostImpl(Dio dio, String baseUrl) {
  final baseUri = Uri.tryParse(baseUrl);
  final host = (baseUri?.host ?? '').toLowerCase();

  final isLocalhost = host == '127.0.0.1' || host == 'localhost' || host == '10.0.2.2';
  if (!isLocalhost) return;

  // Some devices/networks may have a system HTTP proxy configured (often pointing
  // to 127.0.0.1:<port> for debugging tools). That breaks local dev when calling
  // the backend through `adb reverse`. Force DIRECT for localhost targets.
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) => 'DIRECT';
      return client;
    },
  );
}
