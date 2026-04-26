class AppConfig {
  const AppConfig._();

  static const String _embeddedNvidiaApiKey =
      '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';
  static const String _definedNvidiaApiKey = String.fromEnvironment(
    'NVIDIA_API_KEY',
  );
  static const String _definedNvidiaBaseUrl = String.fromEnvironment(
    'NVIDIA_BASE_URL',
    defaultValue: 'https://integrate.api.nvidia.com/v1',
  );

  static String get nvidiaApiKey {
    final String envValue = _definedNvidiaApiKey.trim();
    if (envValue.isNotEmpty) {
      return envValue;
    }
    return _embeddedNvidiaApiKey;
  }

  static String get nvidiaBaseUrl => _definedNvidiaBaseUrl;
}
