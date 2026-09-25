/// AI 服务：调用 AI 生成叙事与选项。
///
/// 简化版：单 Key、无重试、无多 Key 轮换。
/// 后续 Batch 可扩展为多 Key 池 + 429 退避。
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/event.dart';
import '../models/player.dart';

/// AI 响应结果。
class AiResponse {
  const AiResponse({
    required this.narrative,
    required this.choices,
    required this.isSuccess,
    this.errorMessage,
  });

  /// 叙事文本。
  final String narrative;

  /// 选项列表。
  final List<EventChoice> choices;

  /// 是否成功。
  final bool isSuccess;

  /// 错误信息。
  final String? errorMessage;
}

/// AI 服务。
class AiService {
  AiService({
    required this.apiKey,
    this.baseUrl = 'https://token.sensenova.cn/v1',
    this.model = 'sensenova-6.8-flash-lite',
    Dio? dio,
  }) : _dio = dio ?? Dio();

  final String apiKey;
  final String baseUrl;
  final String model;
  final Dio _dio;

  /// 生成叙事与选项。
  ///
  /// 内置基础容错：HTTP 429 / 网络错误时按指数退避自动重试
  /// （最多 [maxRetries] 次，间隔 1s/2s/4s...），提升可用性。
  Future<AiResponse> generateNarrative({
    required Player player,
    required String context,
    required List<GameEvent> availableEvents,
    int maxTokens = 2000,
    int maxRetries = 3,
  }) async {
    final prompt = _buildPrompt(player, context, availableEvents);
    var attempt = 0;

    while (true) {
      attempt++;
      final response = await _postChat(prompt, maxTokens);
      if (response.isSuccess) return response;

      // 可重试的错误：429 / 网络错误 / 5xx；其余直接返回
      final msg = response.errorMessage ?? '';
      final retryable = msg.contains('429') ||
          msg.contains('timed out') ||
          msg.contains('Connection') ||
          msg.contains('Network error') ||
          msg.contains('SocketException') ||
          msg.startsWith('HTTP 5');
      if (!retryable || attempt > maxRetries) return response;

      // 指数退避：1s / 2s / 4s ...
      final delay = Duration(milliseconds: 500 * (1 << (attempt - 1)) * 2);
      await Future<void>.delayed(delay);
    }
  }

  /// 发起一次 chat/completions 请求并解析。
  Future<AiResponse> _postChat(String prompt, int maxTokens) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': maxTokens,
          'temperature': 0.7,
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final content = data['choices'][0]['message']['content'] as String;
        return _parseResponse(content);
      } else {
        return AiResponse(
          narrative: '',
          choices: <EventChoice>[],
          isSuccess: false,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      return AiResponse(
        narrative: '',
        choices: <EventChoice>[],
        isSuccess: false,
        errorMessage: e.message ?? 'Network error',
      );
    } catch (e) {
      return AiResponse(
        narrative: '',
        choices: <EventChoice>[],
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// 构建用户提示词。
  String _buildPrompt(
    Player player,
    String context,
    List<GameEvent> availableEvents,
  ) {
    final eventsDesc = availableEvents
        .map((e) => '- ${e.name}: ${e.description}')
        .join('\n');

    return '''
当前玩家状态：
- 姓名：${player.name}
- 身份：${player.identity.name}
- 家族：${player.familyId}
- 年龄：${player.age}
- 地点：${player.locationId}
- 金币：${player.gold}
- 声望：${player.reputation}
- 技能：${player.skills}
- 属性：${player.attributes}

当前情境：
${context}

可用事件：
${eventsDesc}

请生成一段叙事文本（200-500 字），描述当前情境，并提供 2-4 个选项。
每个选项包含：文本、效果（JSON 格式）、叙事。

输出格式（JSON）：
{
  "narrative": "叙事文本",
  "choices": [
    {
      "text": "选项文本",
      "effects": {"gold": 10, "reputation": 5},
      "narrative": "选择后的叙事"
    }
  ]
}
''';
  }

  /// 解析 AI 响应。
  AiResponse _parseResponse(String content) {
    try {
      // 尝试提取 JSON
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
      if (jsonMatch == null) {
        return AiResponse(
          narrative: content,
          choices: <EventChoice>[],
          isSuccess: true,
        );
      }

      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final narrative = json['narrative'] as String? ?? '';
      final choicesData = json['choices'] as List? ?? <dynamic>[];

      final choices = choicesData
          .map((c) => EventChoice(
                id: 'choice_${DateTime.now().millisecondsSinceEpoch}',
                text: c['text'] as String? ?? '',
                requirements: const <String, int>{},
                effects: (c['effects'] as Map? ?? <String, dynamic>{})
                    .cast<String, int>(),
                narrative: c['narrative'] as String? ?? '',
              ))
          .toList();

      return AiResponse(
        narrative: narrative,
        choices: choices,
        isSuccess: true,
      );
    } catch (_) {
      return AiResponse(
        narrative: content,
        choices: <EventChoice>[],
        isSuccess: true,
      );
    }
  }

  /// System Prompt（参考 docs/07_AI提示词.md）。
  static const String systemPrompt = '''
你是【维斯特洛世界模拟系统】。

你不是小说作者，不是传统 RPG 的 GM，不是任务发布器，不是爽文导演。
你是维斯特洛世界模拟系统，负责维护：
- 家族、政治、宗教、战争、经济、魔法
- 龙、异鬼、长城、守夜人、学城、教会
- NPC、历史、时间、因果、季节、凛冬

玩家负责自己的人生。

核心原则：
1. 世界不围绕玩家存在
2. 玩家可以是任何人
3. 历史不会停止
4. 家族不是职业
5. 封建权力结构复杂

输出要求：
- 叙事文本 200-500 字
- 提供 2-4 个选项
- 每个选项包含效果（JSON 格式）
- 保持维斯特洛世界观一致性
''';
}