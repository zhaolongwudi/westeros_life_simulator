/// AI 服务：调用 AI 生成叙事与选项。
///
/// 简化版：单 Key、无重试、无多 Key 轮换。
/// 后续 Batch 可扩展为多 Key 池 + 429 退避。
library;
import 'dart:convert';
import 'package:dio/dio.dart';
import '../data/location_data.dart';
import '../data/narrative_templates.dart';
import '../data/npc_data.dart';
import '../models/event.dart';
import '../models/player.dart';
import '../utils/labels.dart';

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
    String season = '',
    int currentYear = 0,
    int maxTokens = 2000,
    int maxRetries = 3,
  }) async {
    final prompt = _buildPrompt(player, context, availableEvents, season, currentYear);
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
    String season,
    int currentYear,
  ) {
    final eventsDesc = availableEvents
        .map((e) => '- ${e.name}: ${e.description}')
        .join('\n');
    final relationDesc = player.relations.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('、');
    // Batch 10-15：注入在场 NPC 关系（名字 + 关系值 + 心情 + 任务）
    final onSiteNpcDesc = allNpcs
        .where((n) => n.isAlive && n.locationId == player.locationId)
        .map((n) {
      final rel = player.relations[n.id] ?? 0;
      return '${n.name}（关系 $rel${n.mood.isEmpty ? '' : '，心情${n.mood}'}'
          '${n.tasks.isEmpty ? '' : '，可委托${n.tasks.first}'}）';
    }).join('、');
    final flagDesc = player.flags.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .join('、');
    final inventoryDesc = player.inventory.isEmpty
        ? '（空）'
        : player.inventory.join('、');
    final titleDesc = player.title.isEmpty ? '（无）' : player.title;
    // Batch 10-19：注入婚姻状态/子女培养/进行中任务
    final marriageDesc = player.spouse == null
        ? '（未婚）'
        : '配偶 ${player.spouse!.name}（${player.spouse!.origin.name}，'
            '结婚 ${currentYear <= 0 ? "?" : currentYear - player.spouse!.marriedYear} 年）';
    final childDesc = player.children.isEmpty
        ? '（无子女）'
        : player.children
            .map((c) {
              final r = player.childRearing.where((x) => x.name == c).toList();
              if (r.isEmpty) return c;
              final focus = r.first.focus.isEmpty ? '' : '（培养 ${r.first.focus}）';
              final school = r.first.sentToSchool ? '（进修中）' : '';
              return '$c$focus$school';
            })
            .join('、');
    final taskDesc = player.activeTasks.isEmpty
        ? '（无进行中任务）'
        : player.activeTasks
            .map((t) => '${t.title}（${t.completed ? "已完成" : t.failed ? "已失败" : "进行中 ${t.stepIndex} 步"}）')
            .join('、');
    final equipmentDesc = player.flags.entries
        .where((e) => e.key.startsWith('equipped.') && e.value)
        .map((e) => e.key.substring(9))
        .join('、');
    // Batch 10-9：差异化叙事引导（身份 / 区域 / 季节）
    final idGuide = identityNarrativeGuide(player.identity);
    String region = '';
    for (final l in allLocations) {
      if (l.id == player.locationId) {
        region = l.region;
        break;
      }
    }
    final regionGuide = regionNarrativeGuide(region);
    final seasonGuide = seasonNarrativeGuide(season);
    return '''
当前玩家状态：
- 姓名：${player.name}
- 身份：${identityLabel(player.identity)}
- 头衔：$titleDesc
- 家族：${player.familyId}
- 年龄：${player.age}
- 地点：${player.locationId}（${region.isEmpty ? '未知区域' : region}）
- 金币：${player.gold}
- 声望：${player.reputation}
- 生命/精力/饱食：${player.health}/${player.energy}/${player.hunger}
- 技能：${player.skills}
- 属性：${player.attributes}
- 关系（NPC: 好感度）：${relationDesc.isEmpty ? '（无）' : relationDesc}
- 在场 NPC：${onSiteNpcDesc.isEmpty ? '（无）' : onSiteNpcDesc}
- 背包：$inventoryDesc
- 已装备：${equipmentDesc.isEmpty ? '（无）' : equipmentDesc}
- 婚姻：$marriageDesc
- 子女：$childDesc
- 进行中任务：$taskDesc
- 状态：${flagDesc.isEmpty ? '（无特殊状态）' : flagDesc}
当前情境：
${context}
可用事件：
${eventsDesc}
叙事引导（身份）：
$idGuide
叙事引导（区域）：
$regionGuide
叙事引导（季节）：
$seasonGuide
请生成一段叙事文本（200-500 字），描述当前情境，并提供 2-4 个选项。
每个选项包含：文本、效果（JSON 格式）、叙事。
效果键约定：
- 金币：gold
- 声望：reputation
- 技能：skills.技能名（如 skills.sword）
- 属性：attributes.属性名（如 attributes.strength）
- 关系：relations.NPC标识（正数加好感，负数降好感，如 relations.tyrion: 10）
- 世界状态：flags.标记名（正值设置标记，如 flags.honor_pledge: 1；0 或负值清除标记）
- 生存状态：health / energy / hunger（如 health: 10 回血，energy: -15 耗精力，hunger: 20 进食）
- 物品：inventory.物品ID（正数获得物品，如 inventory.item_bread: 1；负数消耗/丢弃）

输出格式（JSON）：
{
  "narrative": "叙事文本",
  "choices": [
    {
      "text": "选项文本",
      "effects": {"gold": 10, "reputation": 5, "skills.sword": 1, "relations.tyrion": 10, "flags.honor_pledge": 1, "inventory.item_bread": 1},
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
6. 每个选择都有代价，没有免费午餐
7. 玩家的身份决定他能看到的世界——贵族看到权力与阴谋，平民看到税赋与生计，学士看到知识与秘密，守夜人看到长城外的黑暗

叙事要求：
- 叙事文本 200-500 字，用具体的场景、对话、气味、天气来营造氛围
- 不要写“你感到危险”，要写“守夜人的火炬在风中摇晃，墙外的狼嚎断断续续”
- 选项要体现代价与机会：有的选项让玩家变强但树敌，有的选项需要放弃某些东西
- 效果键必须严格遵循约定，数值要合理（技能+1~3，属性+1~2，关系±5~20）
- 保持维斯特洛世界观一致性：季节、家族、地点、历史事件都要准确
''';
}