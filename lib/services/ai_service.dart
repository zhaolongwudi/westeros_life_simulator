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
import '../data/npc_task_data.dart';
import '../data/family_data.dart';
import '../data/item_data.dart';
import '../data/balance_data.dart';
import '../models/event.dart';
import '../models/family.dart';
import '../models/player.dart';
import '../utils/labels.dart';
import 'event_prompt_filter.dart';

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
    String? apiKey,
    this.apiKeys = const <String>[],
    this.baseUrl = 'https://token.sensenova.cn/v1',
    this.model = 'sensenova-6.8-flash-lite',
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    // 兼容：单 key 入参加入池（前置优先）。
    final all = <String>[...apiKeys];
    if (apiKey != null && apiKey.isNotEmpty && !all.contains(apiKey)) {
      all.insert(0, apiKey);
    }
    _apiKeys = all.where((k) => k.isNotEmpty).toList();
  }

  final String baseUrl;
  final String model;
  final Dio _dio;

  /// 多 API Key 池（构造后归一化，保证非空且无重复）。
  late final List<String> _apiKeys;

  /// 本轮起始轮换偏移（静态，跨实例滚动，均匀分散流量）。
  static int _roundRobinOffset = 0;

  /// 可用的 API Key 池（测试与调试用）。
  List<String> get apiKeys => List<String>.unmodifiable(_apiKeys);

  /// 兼容旧字段：主 key（池中第一个）。
  String get apiKey => _apiKeys.isEmpty ? '' : _apiKeys.first;

  /// 生成叙事与选项。
  ///
  /// 内置容错（Batch 10-59 升级）：
  /// 1. **多 Key 轮换**：请求失败（429 / 网络错误 / 5xx）时自动换下一个 Key 重试，
  ///    遍历整个 Key 池后才放弃——避免单个 Key 限流导致 AI 功能不可用。
  /// 2. 单 Key 路径完全向后兼容（池只有 1 个 key，等价于旧版指数退避重试）。
  /// 3. 起始 key 按 round-robin 偏移，让多个 key 均匀分摊流量。
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
    if (_apiKeys.isEmpty) {
      return AiResponse(
        narrative: '',
        choices: <EventChoice>[],
        isSuccess: false,
        errorMessage: '未配置 API Key',
      );
    }

    // round-robin 起始偏移：让每次请求从不同 key 开始，均匀分摊。
    final startIndex = _roundRobinOffset % _apiKeys.length;
    _roundRobinOffset = (_roundRobinOffset + 1) % _apiKeys.length;

    // 遍历整个 key 池：每个 key 最多重试 maxRetries 次（指数退避）。
    var lastResponse = AiResponse(
      narrative: '',
      choices: <EventChoice>[],
      isSuccess: false,
      errorMessage: '未知错误',
    );

    for (var i = 0; i < _apiKeys.length; i++) {
      final keyIndex = (startIndex + i) % _apiKeys.length;
      final key = _apiKeys[keyIndex];
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        final response = await _postChat(prompt, maxTokens, apiKey: key);
        if (response.isSuccess) return response;

        lastResponse = response;
        // 可重试的错误：429 / 网络错误 / 5xx；其余直接放弃当前 key，换下一个。
        final msg = response.errorMessage ?? '';
        final retryable = msg.contains('429') ||
            msg.contains('timed out') ||
            msg.contains('Connection') ||
            msg.contains('Network error') ||
            msg.contains('SocketException') ||
            msg.startsWith('HTTP 5');
        if (!retryable) break;

        if (attempt >= maxRetries) break; // 当前 key 重试耗尽，换下一个 key

        // 指数退避：1s / 2s / 4s ...
        final delay = Duration(milliseconds: 500 * (1 << attempt) * 2);
        await Future<void>.delayed(delay);
      }
    }
    return lastResponse;
  }

  /// 发起一次 chat/completions 请求并解析。
  Future<AiResponse> _postChat(String prompt, int maxTokens,
      {String? apiKey}) async {
    final key = apiKey ?? (_apiKeys.isEmpty ? '' : _apiKeys.first);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
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
    final selectedEvents = selectEventsForPrompt(
      availableEvents,
      player: player,
      season: season,
    );
    final eventsDesc = selectedEvents
        .map((e) => '- ${e.name}: ${e.description}')
        .join('\n');
    // Batch 10-45：注入本月世界局势——从相关度最高的预算内事件取前 2 条，
    // 让 AI 叙事围绕当前世界大事展开（复用事件预算筛选器的相关度排序）。
    final worldNews = selectedEvents.take(2).toList();
    final worldNewsDesc = worldNews.isEmpty
        ? '（本月暂无重大传闻）'
        : worldNews
            .map((e) => '· ${e.name}——${e.description}')
            .join('\n');
    // Batch 10-50：注入季节世界动向——当前季节下整个维斯特洛的宏观变化，
    // 与玩家视角的叙事引导互补，让 AI 围绕「季节驱动世界」展开叙事。
    final seasonTrendDesc = seasonWorldTrend(season);
    final relationDesc = player.relations.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('、');
    // Batch 10-15：注入在场 NPC 关系（名字 + 关系值 + 心情 + 任务）
    // Batch 10-22：在场 NPC 多步骤任务模板注入（标题 + 难度 + 期限，替代旧 tasks.first）
    final onSiteNpcDesc = allNpcs
        .where((n) => n.isAlive && n.locationId == player.locationId)
        .map((n) {
      final rel = player.relations[n.id] ?? 0;
      final templates = npcTaskTemplatesOf(n.id);
      final taskPart = templates.isEmpty
          ? ''
          : '，可委托：${templates.map((t) => '「${t.title}」（${t.typeLabel}，难度 ${t.difficulty}，期限 ${t.deadlineMonths} 月）').join('、')}';
      return '${n.name}（关系 $rel${n.mood.isEmpty ? '' : '，心情${n.mood}'}$taskPart）';
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
        : '配偶 ${player.spouse!.name}（${spouseOriginLabel(player.spouse!.origin)}，'
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
    // Batch 10-20：注入世代谱系（历代家主）与头衔晋升进度
    final lineageDesc = player.generationRecords.isEmpty
        ? '（第一代家主）'
        : '第 ${player.generationRecords.length + 1} 代，先祖：'
            '${player.generationRecords.map((g) => '${g.generation}代 ${g.name}（${g.title}${g.achievement.isEmpty ? '' : "，${g.achievement}"}）').join(' → ')}';
    // Batch 10-22：注入家族信息（名称/族语/规模/影响力）
    Family? playerFamily;
    for (final f in allFamilies) {
      if (f.id == player.familyId) {
        playerFamily = f;
        break;
      }
    }
    final String familyDesc;
    final pf = playerFamily;
    if (pf == null) {
      familyDesc = '（自由民，无家族）';
    } else {
      final scaleLabel = pf.scale == FamilyScale.great
          ? '大家族'
          : pf.scale == FamilyScale.minor
              ? '小家族'
              : '家户';
      familyDesc = '${pf.name}家族（族语「${pf.motto}」，$scaleLabel，影响力 ${pf.influence}）';
    }
    // Batch 10-48：注入头衔晋升趋势——用 balance_data 单一真相量化「下一档头衔 + 所需声望」，
    // 取代旧的距离描述（90/70 魔法数字），让 AI 叙事能围绕玩家的头衔目标展开。
    final String titleProgressDesc;
    if (player.title.isEmpty) {
      titleProgressDesc = '（暂无头衔）';
    } else {
      final ladder = BalanceData.ladderOf(player.identity.name);
      final nextRep = BalanceData.nextTierReputation(
        player.identity.name,
        player.reputation,
      );
      // 取下一档头衔名（避免依赖 collection 扩展，用 for 循环）。
      String nextTitle = '';
      for (final tier in ladder) {
        if (tier.reputation == nextRep) {
          nextTitle = tier.title;
          break;
        }
      }
      final ladderDesc = ladder
          .map((t) => '${t.title}(${t.reputation})')
          .join(' → ');
      titleProgressDesc = nextRep == 0
          ? '当前头衔 ${player.title}，声望 ${player.reputation}/100，已登顶本身份头衔巅峰（阶梯：$ladderDesc）'
          : '当前头衔 ${player.title}，声望 ${player.reputation}/100，距下一档「$nextTitle」还差 ${nextRep - player.reputation} 声望（阶梯：$ladderDesc）';
    }
    final equipmentDesc = player.flags.entries
        .where((e) => e.key.startsWith('equipped.') && e.value)
        .map((e) {
      final item = itemById(e.key.substring(9));
      if (item == null) return e.key.substring(9);
      return '${item.name}（${itemCategoryLabel(item.category)}，价值 ${item.value}）';
    })
        .join('、');
    // Batch 10-43：注入装备战力（与 mixin_life.combatPower 同算法：技能×2 + 力量/2 + 装备加成）
    final combatDesc = combatPowerOf(player);
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
    // Batch 10-52：注入地区风土人情——当前所在区域的宏观气质与常态底色，
    // 与玩家视角的区域引导互补，让 AI 围绕「区域驱动世界」展开叙事，
    // 与季节世界动向形成「时节 × 地域」双轴。
    final regionTrendDesc = regionWorldTrend(region);
    // Batch 10-56：注入时节农事——当前季节 × 当前区域的生计实事
    // （农事/集市/物产/行当），让 AI 围绕「此时此地人们靠什么活着」展开，
    // 与季节世界动向、地区风土人情形成「时节 × 地域 × 生计」三轴。
    final farmTrendDesc = seasonFarmTrend(season, region);
    // Batch 10-58：注入本地集市行情——当前季节 × 当前区域的集市行情风向
    // （什么好卖/什么贵/什么滞销/物价起伏），让 AI 围绕「此时此地买卖什么划算」
    // 展开叙事，与季节世界动向/地区风土人情/时节农事形成「时节 × 地域 × 生计 × 集市」四轴。
    final marketTrendDesc = localMarketTrend(season, region);
    final seasonGuide = seasonNarrativeGuide(season);
    return '''
当前玩家状态：
- 姓名：${player.name}
- 身份：${identityLabel(player.identity)}
- 头衔：$titleDesc
- 头衔晋升：$titleProgressDesc
- 世代谱系：$lineageDesc
- 家族：$familyDesc
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
- 战斗值：$combatDesc
- 婚姻：$marriageDesc
- 子女：$childDesc
- 进行中任务：$taskDesc
- 状态：${flagDesc.isEmpty ? '（无特殊状态）' : flagDesc}
当前情境：
${context}
本月世界局势：
${worldNewsDesc}
季节世界动向：
${seasonTrendDesc}
地区风土人情：
${regionTrendDesc}
时节农事：
${farmTrendDesc}
本地集市行情：
${marketTrendDesc}
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

  /// 装备战力（与 mixin_life.combatPower 同算法，Batch 10-43）。
  ///
  /// 技能（sword×2 + archery） + 力量/2 + 装备加成（武器价值/20、护甲价值/30、坐骑 +2）。
  /// 服务于 AI prompt 注入，避免与混入层实现的算法分叉。
  static int combatPowerOf(Player player) {
    var power = (player.skills['sword'] ?? 0) * 2 + (player.skills['archery'] ?? 0);
    power += (player.attributes['strength'] ?? 0) ~/ 2;
    for (final e in player.flags.entries) {
      if (!(e.key.startsWith('equipped.') && e.value)) continue;
      final item = itemById(e.key.substring(9));
      if (item == null) continue;
      switch (item.category) {
        case ItemCategory.weapon:
          power += item.value ~/ 20;
        case ItemCategory.armor:
          power += item.value ~/ 30;
        case ItemCategory.mount:
          power += 2;
        default:
          break;
      }
    }
    return power;
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