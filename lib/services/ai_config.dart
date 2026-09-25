/// AI 配置存储：API Key / 模型 / BaseURL。
///
/// 使用 SharedPreferences 持久化，供主界面 AI 叙事调用。
library;

import 'package:shared_preferences/shared_preferences.dart';

/// AI 配置。
class AiConfig {
  const AiConfig({
    required this.apiKey,
    required this.model,
    required this.baseUrl,
  });

  final String apiKey;
  final String model;
  final String baseUrl;

  /// 默认配置（商汤 SenseNova，参考 ai_service 默认值）。
  factory AiConfig.defaultConfig() {
    return const AiConfig(
      apiKey: '',
      model: 'sensenova-6.8-flash-lite',
      baseUrl: 'https://token.sensenova.cn/v1',
    );
  }

  /// 是否已配置 API Key。
  bool get isConfigured => apiKey.isNotEmpty;

  /// 从 SharedPreferences 读取。
  static Future<AiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final config = AiConfig.defaultConfig();
    return AiConfig(
      apiKey: prefs.getString('ai_api_key') ?? config.apiKey,
      model: prefs.getString('ai_model') ?? config.model,
      baseUrl: prefs.getString('ai_base_url') ?? config.baseUrl,
    );
  }

  /// 保存到 SharedPreferences。
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', apiKey);
    await prefs.setString('ai_model', model);
    await prefs.setString('ai_base_url', baseUrl);
  }

  /// 清空 API Key。
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_api_key');
  }
}