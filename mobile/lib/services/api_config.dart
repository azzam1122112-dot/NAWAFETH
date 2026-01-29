class ApiConfig {
  static const String _baseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nawafeth-backend.onrender.com',
  );

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

    // Production-safe default.
    return 'https://nawafeth-backend.onrender.com';
  }

  static const String apiPrefix = '/api';
}
