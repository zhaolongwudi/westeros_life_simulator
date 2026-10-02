/// AI 提供商预设（Batch 10-59 新增，参考 hogwarts 的 provider_defaults）。
///
/// 单一真相对齐：提供商名称 / 展示名 / 默认模型 / 模型候选列表 / BaseURL
/// 都从这里读，settings 页与 ai_config 不再各写一份。
library;

/// 一个 AI 提供商的预设默认值。
class AiProviderDefaults {
  const AiProviderDefaults({
    required this.name,
    required this.label,
    required this.model,
    required this.models,
    required this.baseUrl,
  });

  /// 内部标识（持久化到配置的 provider 字段）。
  final String name;

  /// 展示名。
  final String label;

  /// 默认模型。
  final String model;

  /// 模型候选列表（设置页下拉用）。
  final List<String> models;

  /// 默认 BaseURL（不含 /v1 后缀，发请求时由服务拼接）。
  final String baseUrl;

  /// 便捷：转换为「含 /v1 的完整 chat/base 路径」。
  String get chatBaseUrl =>
      baseUrl.endsWith('/v1') ? baseUrl : '$baseUrl/v1';
}

/// 内置 AI 提供商预设。
const List<AiProviderDefaults> kAiProviderDefaults = <AiProviderDefaults>[
  AiProviderDefaults(
    name: 'sensenova',
    label: '商汤 SenseNova',
    model: 'sensenova-6.8-flash-lite',
    models: <String>[
      'sensenova-6.8-flash-lite',
      'sensenova-6.8-pro',
      'sensenova-u1-fast',
    ],
    baseUrl: 'https://token.sensenova.cn',
  ),
  AiProviderDefaults(
    name: 'atria',
    label: 'Atria ASI',
    model: 'Atria-Dawn-Preview',
    models: <String>[
      'Atria-Dawn-Preview',
      'Atria-Sunrise-Pro',
      'Atria-Sunrise-Flash',
    ],
    baseUrl: 'https://api.atria-asi.ai',
  ),
  AiProviderDefaults(
    name: 'deepseek',
    label: 'DeepSeek',
    model: 'deepseek-chat',
    models: <String>[
      'deepseek-chat',
      'deepseek-reasoner',
    ],
    baseUrl: 'https://api.deepseek.com',
  ),
];

/// 按提供商名取预设；未知回落到第一个（sensenova）。
AiProviderDefaults providerDefaultsOf(String name) {
  for (final d in kAiProviderDefaults) {
    if (d.name == name) return d;
  }
  return kAiProviderDefaults.first;
}