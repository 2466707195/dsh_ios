/// 应用设置（API 配置）
class AppSettings {
  final String apiKey;
  final String baseUrl;
  final String model;

  static const defaultBaseUrl = 'https://api.deepseek.com';
  static const defaultModel = 'deepseek-flash';

  const AppSettings({
    this.apiKey = '',
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
  });

  bool get isConfigured => apiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? apiKey,
    String? baseUrl,
    String? model,
  }) =>
      AppSettings(
        apiKey: apiKey ?? this.apiKey,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
      );
}
