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
  String get chatBaseUrl => normalizeOpenAiBaseUrl(baseUrl);
}

/// 把用户/预设填的 BaseURL 归一化成 OpenAI 兼容的 `<host>/v1` 形式（无尾斜杠）。
///
/// 【为什么需要它】本项目曾有 **4 份** `baseUrl.endsWith('/v1') ? baseUrl : '$baseUrl/v1'`
/// （`ai_config.dart` / `ai_provider_defaults.dart` / `settings_screen.dart` ×2），
/// 逻辑相同但都只认「恰好以 `/v1` 结尾」：
/// - `https://x/v1/`（用户最常见的粘贴形态，带尾斜杠）⇒ 拼成 `https://x/v1//v1` ⇒ **必 404**
/// - `https://x/` ⇒ `https://x//v1` ⇒ 多半 404
/// - `https://x/v1/chat/completions`（用户直接粘完整端点）⇒ `.../chat/completions/v1` ⇒ 404
///
/// 【本函数的契约】输入任意形态 → 输出「恰好一个 `/v1`、无尾斜杠」的 host 形式。
/// 已是 `/v1`（含尾斜杠）原样保留；否则先去掉所有尾斜杠，再判断是否已含 `/v1`
/// 前缀（含 `/v1` 的更长路径如 `/v1/chat/completions` 会被裁到 `/v1`——因为本项目
/// 的 [AiService] 自己会在 base 后面拼 `/chat/completions` 与 `/models`）。
String normalizeOpenAiBaseUrl(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  // 去掉尾斜杠（可能有多个）
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  // 若用户粘了完整的 /chat/completions 或 /models 端点，裁回 host
  s = s.replaceFirst(RegExp(r'/chat/completions$'), '');
  s = s.replaceFirst(RegExp(r'/models$'), '');
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.isEmpty) return s;
  // 判是否已含 /v1 路径段（结尾或被 / 跟随）
  if (RegExp(r'/v1(/|$)').hasMatch(s)) return s;
  return '$s/v1';
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