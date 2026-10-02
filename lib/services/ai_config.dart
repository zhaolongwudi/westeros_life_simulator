/// AI 配置存储：多 API Key 池 / 模型 / BaseURL / 提供商。
///
/// 使用 SharedPreferences 持久化，供主界面 AI 叙事调用。
/// Batch 10-59：升级为多 key（JSON 数组）+ 提供商预设（provider），
/// 并向后兼容旧版单 key（api_key 明文键）。
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/ai_provider_defaults.dart';

/// AI 配置。
class AiConfig {
  const AiConfig({
    this.apiKeys = const <String>[],
    String? apiKey,
    this.model = '',
    this.baseUrl = '',
    this.provider = 'sensenova',
  }) : _legacyApiKey = apiKey;

  /// 多 API Key 池（按顺序轮换）。
  final List<String> apiKeys;

  /// 旧版单 key（兼容构造入参，仅当 apiKeys 为空时生效）。
  final String? _legacyApiKey;

  /// 模型名（空则用 provider 默认）。
  final String model;

  /// BaseURL（空则用 provider 默认）。
  final String baseUrl;

  /// 提供商预设名（sensenova / atria / deepseek）。
  final String provider;

  /// 兼容旧字段：主 key（池中第一个；无池时回落构造入参的单 key）。
  String get apiKey {
    if (apiKeys.isNotEmpty) return apiKeys.first;
    return _legacyApiKey ?? '';
  }

  /// 是否已配置至少一个 API Key。
  bool get isConfigured {
    if (_legacyApiKey != null && _legacyApiKey.isNotEmpty) return true;
    return apiKeys.isNotEmpty && apiKeys.any((k) => k.isNotEmpty);
  }

  /// 解析后的模型（空则回落到 provider 默认模型）。
  String get resolvedModel {
    if (model.isNotEmpty) return model;
    return providerDefaultsOf(provider).model;
  }

  /// 解析后的 BaseURL（空则回落到 provider 默认；带 /v1）。
  String get resolvedBaseUrl {
    if (baseUrl.isNotEmpty) {
      return baseUrl.endsWith('/v1') ? baseUrl : '$baseUrl/v1';
    }
    return providerDefaultsOf(provider).chatBaseUrl;
  }

  /// 默认配置（商汤 SenseNova，参考 ai_service 默认值；
  /// 与 provider 默认回落等价，但保留显式 model/baseUrl 兼容旧测试断言）。
  factory AiConfig.defaultConfig() {
    return const AiConfig(
      apiKeys: <String>[],
      model: 'sensenova-6.8-flash-lite',
      baseUrl: 'https://token.sensenova.cn/v1',
      provider: 'sensenova',
    );
  }

  /// 从 SharedPreferences 读取。
  static Future<AiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    // 多 key 优先（Batch 10-59 新格式）
    final keysJson = prefs.getString('ai_api_keys');
    List<String> keys = <String>[];
    if (keysJson != null && keysJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(keysJson);
        if (decoded is List) {
          keys = decoded.whereType<String>().toList();
        }
      } catch (_) {
        keys = <String>[];
      }
    }
    // 兼容旧版单 key：多 key 为空时读旧键
    if (keys.isEmpty) {
      final legacyKey = prefs.getString('ai_api_key') ?? '';
      if (legacyKey.isNotEmpty) keys = <String>[legacyKey];
    }
    final storedProvider = prefs.getString('ai_provider') ?? 'sensenova';
    // 空值回落 provider 默认（保持旧测试与配置页预期一致）。
    final storedModel = prefs.getString('ai_model') ?? '';
    final storedBaseUrl = prefs.getString('ai_base_url') ?? '';
    final defaults = providerDefaultsOf(storedProvider);
    return AiConfig(
      apiKeys: keys,
      model: storedModel.isEmpty ? defaults.model : storedModel,
      baseUrl: storedBaseUrl.isEmpty ? defaults.baseUrl : storedBaseUrl,
      provider: storedProvider,
    );
  }

  /// 保存到 SharedPreferences。
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    // 兼容旧单 key：构造入参的 apiKey 并入池首位，避免 save→load 丢失。
    final all = <String>[...apiKeys];
    if (_legacyApiKey != null &&
        _legacyApiKey.isNotEmpty &&
        !all.contains(_legacyApiKey)) {
      all.insert(0, _legacyApiKey);
    }
    final nonEmpty = all.where((k) => k.trim().isNotEmpty).toList();
    await prefs.setString('ai_api_keys', jsonEncode(nonEmpty));
    await prefs.setString('ai_model', model);
    await prefs.setString('ai_base_url', baseUrl);
    await prefs.setString('ai_provider', provider);
    // 同步旧单 key 键，保持老逻辑兼容
    await prefs.setString('ai_api_key', nonEmpty.isEmpty ? '' : nonEmpty.first);
  }

  /// 清空 API Key。
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_api_keys');
    await prefs.remove('ai_api_key');
  }
}