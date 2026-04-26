class AppConfig {
  const AppConfig._();

  static const String nvidiaApiKey = String.fromEnvironment('NVIDIA_API_KEY');
  static const String nvidiaBaseUrl = String.fromEnvironment(
    'NVIDIA_BASE_URL',
    defaultValue: 'https://integrate.api.nvidia.com/v1',
  );
}
