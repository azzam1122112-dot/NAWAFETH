class ApiConfig {
  static const int _defaultPort = 8000;
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Local development base URL.
  ///
  /// - On Android physical device with `adb reverse tcp:8000 tcp:8000`:
  ///   `http://127.0.0.1:8000`
  /// - On Android emulator:
  ///   `http://10.0.2.2:8000`
  ///
  /// You can override it later if you add env/flavors.
  static String get baseUrl {
    final override = _baseUrlOverride.trim();
    if (override.isNotEmpty) {
      // Normalize trailing slash if provided.
      return override.endsWith('/') ? override.substring(0, override.length - 1) : override;
    }

    // Default to localhost. On Android physical devices use `adb reverse`.
    // If you're using an Android emulator, change this to `10.0.2.2`.
    // FOR CLIENT DEMO (LAN): Use PC IP
    return 'http://192.168.3.2:$_defaultPort';
  }

  static const String apiPrefix = '/api';
}
