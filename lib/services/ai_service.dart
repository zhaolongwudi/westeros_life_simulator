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
import '../models/location.dart';
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
    List<String> apiKeys = const <String>[],
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
  /// 内置容错（Batch 10-59 升级 + 用户反馈 Batch 10-59-fix1）：
  /// 1. **多 Key 每次请求自动轮换**：不等待失败，每次请求直接用下一个 Key；
  ///    失败（429/网络/5xx）也不重试同一个 Key，直接换下一个——避免反复打
  ///    同一个 Key 触发其 TPM/RPM 限流。遍历整个 Key 池后才放弃。
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

    var lastResponse = AiResponse(
      narrative: '',
      choices: <EventChoice>[],
      isSuccess: false,
      errorMessage: '未知错误',
    );

    if (_apiKeys.length == 1) {
      // 单 Key：等价旧版指数退避重试（batch9 契约）。
      final key = _apiKeys.first;
      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        final response = await _postChat(prompt, maxTokens, apiKey: key);
        if (response.isSuccess) return response;
        lastResponse = response;
        final msg = response.errorMessage ?? '';
        final retryable = msg.contains('429') ||
            msg.contains('timed out') ||
            msg.contains('Connection') ||
            msg.contains('Network error') ||
            msg.contains('SocketException') ||
            msg.startsWith('HTTP 5');
        if (!retryable || attempt >= maxRetries) break;
        final delay = Duration(milliseconds: 500 * (1 << attempt) * 2);
        await Future<void>.delayed(delay);
      }
      return lastResponse;
    }

    // 多 Key：每次请求自动轮换下一个 key，失败直接换 key 不重试同一 key。
    for (var i = 0; i < _apiKeys.length; i++) {
      final keyIndex = (startIndex + i) % _apiKeys.length;
      final key = _apiKeys[keyIndex];
      final response = await _postChat(prompt, maxTokens, apiKey: key);
      if (response.isSuccess) return response;
      lastResponse = response;
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
      // 优先用 HTTP 状态码（含 429 等限流语义）；无 status 时回落网络错误。
      final status = e.response?.statusCode;
      final msg = status != null ? 'HTTP $status' : (e.message ?? 'Network error');
      return AiResponse(
        narrative: '',
        choices: <EventChoice>[],
        isSuccess: false,
        errorMessage: msg,
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
    // Batch 10-70：注入当前局势关联 NPC 立场——让 AI 知道「谁在这场风波中站在哪边」。
    // 复用 top2 世界事件，对玩家关系 NPC（取前 3 个）按其家族对外关系网络
    // （family.relations 敌友阈值 ±20）推导立场：
    //   - 局势事件涉及某家族 → 相关 NPC 的家族与谁敌对/友善
    //   - 玩家与 NPC 的好感度也一并提示（AI 知道玩家站在谁那边有风险）
    // 让 AI 的政治叙事有「人物 × 局势」的立场支撑，而不只是干巴巴的事件列表。
    final stanceDesc = _worldStanceDesc(player, worldNews);
    // Batch 10-50：注入季节世界动向——当前季节下整个维斯特洛的宏观变化，
    // 与玩家视角的叙事引导互补，让 AI 围绕「季节驱动世界」展开叙事。
    final seasonTrendDesc = seasonWorldTrend(season);
    // Batch 10-64：注入关系 NPC 身份信息——之前只输出「NPC ID: 好感度」，
    // AI 不知道对方是谁（名字/身份/家族/所在地），叙事难以依托人物关系展开。
    // 现在升级为「名字（身份·家族·所在地）: 好感度」，找不到 NPC 时回退原 ID。
    // Batch 10-68：关系 NPC 附加秘密（secrets 前 1 条，空则省略）——AI 能围绕
    // NPC 隐藏秘密（如琼恩·雪诺的真实身份）展开更深的剧情。
    final relationDesc = player.relations.entries
        .map((e) {
          final n = npcById(e.key);
          if (n == null) return '${e.key}: ${e.value}';
          final fam = familyById(n.familyId);
          final loc = locationById(n.locationId);
          final famText = fam == null ? '无家族' : '${fam.name}家族';
          final locText = loc == null ? '未知之地' : loc.name;
          final secretText = n.secrets.isEmpty ? '' : '，秘密：${n.secrets.first}';
          return '${n.name}（${npcTypeLabel(n.type)}·$famText·$locText$secretText）: ${e.value}';
        })
        .join('、');
    // Batch 10-73：注入 NPC 间关系网络——AI 之前只知道玩家与每个 NPC 的关系，
    // 不知道这些 NPC 彼此之间谁亲近谁敌对（如艾德与凯特琳是夫妻、詹姆与提利昂
    // 兄弟情仇、卢斯·波顿与史塔克家族势不两立），人物互动叙事缺乏人际张力支撑。
    // 现在取玩家关系 NPC（前 3 个，防 prompt 膨胀）的 `relations` 映射，
    // 输出「A 与 B（关系 N）：敌对/友善/中立」清单。
    final npcNetworkDesc = _npcNetworkDesc(player);
    // Batch 10-15：注入在场 NPC 关系（名字 + 关系值 + 心情 + 任务）
    // Batch 10-22：在场 NPC 多步骤任务模板注入（标题 + 难度 + 期限，替代旧 tasks.first）
    // Batch 10-65：附加性格/目标注入——AI 之前只知道 NPC 名字/关系/心情，
    // 不知道对方性格特质与行事目标，人物叙事缺乏深度；现在附加「性格·目标」。
    final onSiteNpcDesc = allNpcs
        .where((n) => n.isAlive && n.locationId == player.locationId)
        .map((n) {
      final rel = player.relations[n.id] ?? 0;
      final templates = npcTaskTemplatesOf(n.id);
      final taskPart = templates.isEmpty
          ? ''
          : '，可委托：${templates.map((t) => '「${t.title}」（${t.typeLabel}，难度 ${t.difficulty}，期限 ${t.deadlineMonths} 月）').join('、')}';
      // Batch 10-65：性格与目标（各取前 2 条防 prompt 膨胀；空则省略）。
      final traitPart = n.personality.isEmpty
          ? ''
          : '，性格：${n.personality.take(2).join('、')}';
      final goalPart = n.goals.isEmpty
          ? ''
          : '，目标：${n.goals.take(2).join('、')}';
      return '${n.name}（关系 $rel${n.mood.isEmpty ? '' : '，心情${n.mood}'}$traitPart$goalPart$taskPart）';
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
      // Batch 10-66：注入家族对外关系网络——AI 之前只知道家族名称/族语/规模/影响力，
      // 不知道玩家家族与其他家族的恩怨（盟友/宿敌），政治叙事缺乏立场支撑；
      // 现在附加「对外关系：家族名（敌对/中立/友善）」列表。
      final relText = pf.relations.entries
          .map((re) {
            final other = familyById(re.key);
            final otherName = other == null ? re.key : other.name;
            final stance = switch (re.value) {
              < -20 => '敌对',
              > 20 => '友善',
              _ => '中立',
            };
            return '$otherName（$stance ${re.value}）';
          })
          .join('、');
      final relationPart = pf.relations.isEmpty ? '' : '；对外关系：$relText';
      // Batch 10-67：注入家族特质与秘密——AI 之前只知道家族规模/影响力/对外关系，
      // 不知道家族的文化气质（traits）与隐藏秘密（secrets），叙事难以体现家族底蕴；
      // 现在附加「特质：xxx」「秘密：xxx（前 2 条，空则省略）」。
      final traitPart = pf.traits.isEmpty ? '' : '；特质：${pf.traits.join('、')}';
      final secretPart = pf.secrets.isEmpty
          ? ''
          : '；秘密：${pf.secrets.take(2).join('、')}';
      familyDesc = '${pf.name}家族（族语「${pf.motto}」，$scaleLabel，影响力 ${pf.influence}$relationPart$traitPart$secretPart）';
    }
    // Batch 10-71：注入家族谱系成员——AI 之前只看到家族名称/族语/规模/影响力/对外关系/
    // 特质/秘密，不知道家族内部都有谁（哪些同族 NPC 在世、各自身份/所在地/与玩家的关系），
    // 家族叙事缺乏「人」的维度；现在附加「同族成员」清单（取在世，最多 6 个防 prompt 膨胀）。
    final String familyMembersDesc;
    final pmf = playerFamily;
    if (pmf == null) {
      familyMembersDesc = '（自由民，无家族可依附）';
    } else {
      final members =
          npcsByFamily(pmf.id).where((n) => n.isAlive).take(6).toList();
      if (members.isEmpty) {
        familyMembersDesc = '（暂无在世同族）';
      } else {
        familyMembersDesc = members
            .map((n) {
              final loc = locationById(n.locationId);
              final locText = loc == null ? '未知之地' : loc.name;
              final rel = player.relations[n.id] ?? 0;
              return '${n.name}（${npcTypeLabel(n.type)}·$locText，关系 $rel）';
            })
            .join('、');
      }
    }
    // Batch 10-74：注入家族在权力网络中的位置——AI 之前只知道家族对外关系的
    // 数值（family.relations），不知道玩家在其家族权力结构中的具体位置
    // （家主/继承人/普通成员）与家族在七国权力棋盘中的敌友格局。
    // 现在解析玩家所属家族的 relations（家族名 + 敌/友/中立），
    // 并标注玩家在家中的位置（家主/继承人/成员），让 AI 知道玩家
    // 「效忠于谁、与谁为敌、在家族里是什么角色」。
    final familyPowerDesc = _familyPowerDesc(player, playerFamily);
    // Batch 10-75：注入玩家在家族继承顺位中的位置——AI 之前只知道玩家是
    // 「家主/成员」（10-74），不知道有子女时的继承顺位、谁被重点培养，
    // 也不知道无子嗣时继承悬而未决的政治风险。现在附加「- 家族继承顺位：」行
    // （子女按出生顺序标注第一/第二顺位，命中培养档案时附培养方向）。
    final inheritanceDesc = _inheritanceDesc(player, playerFamily);
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
    Location? currentLocation;
    for (final l in allLocations) {
      if (l.id == player.locationId) {
        region = l.region;
        currentLocation = l;
        break;
      }
    }
    // Batch 10-63：注入当前地点详情——让 AI 知道玩家身处何地、周围有什么。
    // 之前只有「地点：location_winterfell（北境）」一行 ID + 区域，AI 完全不知道
    // 地点名/类型/危险度/人口/特色/相连地点，叙事容易脱离地理实境。
    final String locationDesc;
    final cl = currentLocation;
    if (cl == null) {
      locationDesc = '（未知之地）';
    } else {
      final dangerLabel = switch (cl.dangerLevel) {
        <= 2 => '安全',
        <= 5 => '一般',
        <= 8 => '危险',
        _ => '极度危险',
      };
      final featuresText = cl.features.isEmpty ? '无特殊特色' : cl.features.join('、');
      final connectedText = cl.connectedTo.isEmpty
          ? '无相连地点'
          : cl.connectedTo
              .map((cid) {
                for (final l in allLocations) {
                  if (l.id == cid) return l.name;
                }
                return cid;
              })
              .join('、');
      locationDesc = '${cl.name}（${locationTypeLabel(cl.type)}，$dangerLabel，'
          '人口约 ${cl.population}）——${cl.description.isEmpty ? '（无描述）' : cl.description}'
          '；特色：$featuresText；可前往：$connectedText';
    }
    // Batch 10-76：注入当地势力与玩家的立场——`location.governorId` 全库 69 处赋值
    // 却从未进入 AI prompt，AI 只知道「脚下是临冬城」，不知道「此地由谁治下、
    // 该领主与你的家族是敌是友、你自己与他关系如何」。现在附加
    // 「- 当地势力与你的立场：」行（治主名/身份/家族/敌友判定/与玩家关系）。
    final localPowerDesc = _localPowerDesc(player, playerFamily, currentLocation);
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
    // Batch 10-69：注入所在地名人轶事·历史典故——当前所在区域 × 地点的
    // 历史纵深（知名地点的传说/名人轶事/历史典故），让 AI 叙事围绕
    // 「脚下的土地记得什么」展开，与地区风土人情/时节农事/本地集市行情
    // 形成「地理 × 生计 × 集市 × 历史」四轴。
    final loreDesc = locationLore(region, player.locationId);
    final seasonGuide = seasonNarrativeGuide(season);
    return '''
当前玩家状态：
- 姓名：${player.name}
- 身份：${identityLabel(player.identity)}
- 头衔：$titleDesc
- 头衔晋升：$titleProgressDesc
- 世代谱系：$lineageDesc
- 家族：$familyDesc
- 家族成员：$familyMembersDesc
- 家族在权力网络中的位置：$familyPowerDesc
- 家族继承顺位：$inheritanceDesc
- 年龄：${player.age}
- 地点：${player.locationId}（${region.isEmpty ? '未知区域' : region}）
当前地点：
$locationDesc
- 当地势力与你的立场：$localPowerDesc
- 金币：${player.gold}
- 声望：${player.reputation}
- 生命/精力/饱食：${player.health}/${player.energy}/${player.hunger}
- 技能：${player.skills}
- 属性：${player.attributes}
- 关系（NPC: 好感度）：${relationDesc.isEmpty ? '（无）' : relationDesc}
- NPC 间关系网络：${npcNetworkDesc.isEmpty ? '（无）' : npcNetworkDesc}
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
局势关联 NPC 立场：
${stanceDesc}
季节世界动向：
${seasonTrendDesc}
地区风土人情：
${regionTrendDesc}
时节农事：
${farmTrendDesc}
本地集市行情：
${marketTrendDesc}
所在地轶事·历史典故：
${loreDesc}
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

  /// 生成「NPC 间关系网络」描述（Batch 10-73）。
  ///
  /// 取玩家关系 NPC（前 3 个，防 prompt 膨胀），输出这些 NPC 彼此之间的
  /// 关系（`npc.relations` 映射，按阈值 ±20 分敌对/友善/中立）：
  ///   - 艾德·史塔克 ↔ 凯特琳·史塔克（关系 90）：友善
  ///   - 提利昂·兰尼斯特 ↔ 詹姆·兰尼斯特（关系 80）：友善
  ///   - 卢斯·波顿 ↔ 艾德·史塔克（无直接关系）：中立
  /// 让 AI 知道玩家社交圈内部的人际张力，人物互动叙事不再是孤立的
  /// 「玩家 ↔ NPC」二元关系，而是一张有恩怨的网络。
  String _npcNetworkDesc(Player player) {
    // 取玩家关系 NPC（前 3 个），按关系值降序让最重要的人物优先。
    final relatedIds = player.relations.entries
        .where((e) => e.value != 0)
        .toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    final picked = relatedIds.take(3).map((e) => e.key).toList();
    if (picked.length < 2) return '';
    final lines = <String>[];
    for (var i = 0; i < picked.length; i++) {
      final a = npcById(picked[i]);
      if (a == null) continue;
      for (var j = i + 1; j < picked.length; j++) {
        final b = npcById(picked[j]);
        if (b == null) continue;
        // 双向取强的一方（a 看 b 优先，缺失回退 b 看 a）。
        final rel = a.relations[b.id] ?? b.relations[a.id] ?? 0;
        final stance = switch (rel) {
          < -20 => '敌对',
          > 20 => '友善',
          _ => '中立',
        };
        lines.add('${a.name} ↔ ${b.name}（关系 $rel）：$stance');
      }
    }
    return lines.join('、');
  }

  /// 生成「家族在权力网络中的位置」描述（Batch 10-74）。
  ///
  /// 让 AI 知道玩家在七国权力结构中的坐标：
  ///   - 玩家家族（无家族 → 自由民兜底）
  ///   - 玩家在家中的角色：家主（是当前家主）/ 继承人（有立嗣为继承人）/ 普通成员
  ///   - 家族对外关系的盟友/宿敌/中立格局（family.relations 阈值 ±20）
  /// 玩家角色判断：玩家家族与自身同名（house == family.name）且是家族唯一在世
  /// 成员时视为家主；否则看是否被 family 数据标为继承人（简化：取家族 scale
  /// 与玩家头衔综合判断，保守给「成员」）。
  String _familyPowerDesc(Player player, Family? family) {
    if (family == null) {
      return '（自由民，无家族，不受任何家族约束）';
    }
    // 家族对外关系（盟友/宿敌/中立）。
    final relText = family.relations.entries
        .map((re) {
          final other = familyById(re.key);
          final otherName = other == null ? re.key : other.name;
          final stance = switch (re.value) {
            < -20 => '宿敌',
            > 20 => '盟友',
            _ => '中立',
          };
          return '$otherName（$stance，关系 ${re.value}）';
        })
        .join('、');
    final networkText = family.relations.isEmpty
        ? '无明确对外恩怨'
        : '对外格局：$relText';
    // 玩家在家中的角色：家族名 == 玩家姓氏视为家主候选，否则成员。
    final playerRole = player.house == family.name ? '家主' : '成员';
    return '${family.name}家族（玩家为$playerRole）——$networkText';
  }

  /// 生成「玩家在家族继承顺位中的位置」描述（Batch 10-75）。
  ///
  /// Batch 10-74 只告诉 AI 玩家是「家主/成员」，但没有子嗣信息——AI 不知道
  /// 谁会继承家族、谁被重点培养，也不知道无子嗣时的继承悬疑。现在按
  /// `player.children` 的出生顺序标注顺位（第一/第二/第三顺位），命中
  /// `player.childRearing` 的子女附加培养方向与学城进修标记：
  ///   - 瑞德·史塔克（第一顺位，培养 剑术，进修中）
  ///   - 珊莎·史塔克（第二顺位）
  /// 让 AI 的家族政治叙事有「谁将来接班」的继承维度。
  String _inheritanceDesc(Player player, Family? family) {
    if (family == null) {
      return '（自由民，无家族，无继承顺位）';
    }
    if (player.children.isEmpty) {
      return '（${family.name}家族尚无子嗣，继承悬而未决，旁支虎视眈眈）';
    }
    const ordinals = <String>['第一', '第二', '第三', '第四', '第五'];
    final parts = <String>[];
    for (var i = 0; i < player.children.length; i++) {
      if (parts.length >= 4) break;
      final child = player.children[i];
      final order = i < ordinals.length ? ordinals[i] : '第${i + 1}';
      final rearing = player.childRearing
          .where((x) => x.name == child)
          .toList();
      var extra = '';
      if (rearing.isNotEmpty) {
        final r = rearing.first;
        final focusText = r.focus.isEmpty ? '' : '培养 ${r.focus}';
        final schoolText = r.sentToSchool ? '，进修中' : '';
        final tutoredText = r.tutored ? '，已亲自督导' : '';
        final all = '$focusText$schoolText$tutoredText';
        if (all.isNotEmpty) extra = '（$all）';
      }
      parts.add('$child（$order顺位$extra）');
    }
    final tail = player.children.length > parts.length
        ? '（另有 ${player.children.length - parts.length} 名子女不列顺位）'
        : '';
    return '${parts.join('、')}$tail';
  }

  /// 生成「当地势力与玩家的立场」描述（Batch 10-76）。
  ///
  /// `location.governorId`（69 处地点数据赋值）此前从未进入 AI prompt，AI 只知道
  /// 玩家身在何处，不知道脚下这片地由谁治下、该领主与玩家家族是敌是友、玩家
  /// 与他个人关系如何。现在输出：
  ///   - 治主 NPC 名 + 身份 + 家族
  ///   - 治主家族与玩家家族关系（自家领地 / 盟友 / 敌对 / 中立，阈值 ±20）
  ///   - 玩家与治主的个人关系值
  /// 让 AI 能写出「你在敌国领主的治下」这类地理 × 权力交叉叙事。
  String _localPowerDesc(Player player, Family? family, Location? loc) {
    final l = loc;
    if (l == null) {
      return '（未知之地，无从判断当地势力）';
    }
    final governorId = l.governorId;
    if (governorId == null || governorId.isEmpty) {
      return '${l.name}无明确治主（名义上直属领地，地方豪强代管）';
    }
    final governor = npcById(governorId);
    if (governor == null) {
      return '${l.name}的治主数据缺失（$governorId），地方权力真空';
    }
    final govFamily = familyById(governor.familyId);
    final govFamilyName = govFamily == null ? '无家族' : govFamily.name;
    final fam = family;
    String stanceText;
    if (fam == null) {
      stanceText = '你是自由民，不受任何家族旗号庇护';
    } else if (govFamily != null && govFamily.id == fam.id) {
      stanceText = '此地正是${fam.name}家族自家领地';
    } else {
      final rel = fam.relations[govFamily?.id ?? ''];
      if (rel == null) {
        stanceText = '${fam.name}家族与${govFamilyName}家族无明确恩怨';
      } else if (rel > 20) {
        stanceText = '${fam.name}家族与${govFamilyName}家族为盟友（关系 $rel）';
      } else if (rel < -20) {
        stanceText =
            '${fam.name}家族与${govFamilyName}家族敌对（关系 $rel），你在敌对势力治下';
      } else {
        stanceText = '${fam.name}家族与${govFamilyName}家族关系平平（$rel）';
      }
    }
    final rel = player.relations[governor.id];
    final relText = rel == null
        ? '你与治主尚无直接交集'
        : (rel >= 20
            ? '你与治主交好（关系 $rel）'
            : (rel <= -20 ? '你与治主交恶（关系 $rel）' : '你与治主关系平常（$rel）'));
    return '${l.name}由${governor.name}（${npcTypeLabel(governor.type)}·${govFamilyName}家族）治下：$stanceText；$relText';
  }

  /// 生成「局势关联 NPC 立场」描述（Batch 10-70）。
  ///
  /// 基于本月 top2 世界事件，对玩家关系 NPC（取前 3 个，防 prompt 膨胀），
  /// 按其家族对外关系网络推导「事件对 NPC 意味着什么、他会站在哪边」：
  ///   - NPC 家族与事件关键词涉及的家族是敌/友（family.relations 阈值 ±20）
  ///   - 玩家与 NPC 的好感度一并提示，让 AI 知道玩家所处位置的风险
  /// 让 AI 的政治叙事有「人物 × 局势」的立场支撑。
  String _worldStanceDesc(Player player, List<GameEvent> worldNews) {
    if (worldNews.isEmpty) return '（本月暂无重大传闻，各势力按兵不动）';
    // 收集玩家有关系（好感度非 0）的 NPC，取前 3 个。
    final relatedNpcs = player.relations.entries
        .where((e) => e.value != 0)
        .take(3)
        .map((e) => (npcId: e.key, relation: e.value))
        .toList();
    if (relatedNpcs.isEmpty) {
      return '（你与任何势力都无深交，局势如何发展与你关系有限）';
    }
    final lines = <String>[];
    for (final news in worldNews) {
      final eventText = '${news.name}（${news.description}）';
      final npcLines = relatedNpcs.map((rn) {
        final n = npcById(rn.npcId);
        if (n == null) return '· $eventText：${rn.npcId}（关系 ${rn.relation}）立场不明';
        final fam = familyById(n.familyId);
        final stance = _npcStanceFor(fam, news);
        // Batch 10-72：动态立场修饰——玩家与 NPC 关系好坏直接影响其立场倾向。
        // 10-70 只给「与你关系 N」这个静态数值，AI 难以判断玩家身处风波哪一侧；
        // 现在当关系绝对值 ≥20 时追加明确倾向（好感→倾向站在你这边；恶感→可能与你对立），
        // 关系平平则省略，让立场从「家族恩怨」升级为「家族恩怨 × 私人关系」双维动态。
        final personal = rn.relation.abs() >= 20
            ? (rn.relation > 0
                ? '，因与你交好（${n.name}，关系 ${rn.relation}），倾向考虑你的立场'
                : '，因与你结怨（关系 ${rn.relation}），可能与你对立')
            : '';
        return '· $eventText：${n.name}（${fam?.name ?? '无家族'}家族，'
            '与你关系 ${rn.relation}）$stance$personal';
      }).join('\n');
      lines.add(npcLines);
    }
    return lines.join('\n');
  }

  /// 推导单个 NPC 对某局势事件的立场描述（基于家族对外关系网络）。
  ///
  /// 从事件名称/描述中抽取家族关键词（家族名/id），按 family.relations 敌友阈值
  /// （>20 友善 / <-20 敌对）给出「可能站在谁一边」的判断；无家族或抽不到
  /// 关键词时回退中性描述，绝不抛。
  String _npcStanceFor(Family? fam, GameEvent news) {
    if (fam == null) return '立场随局势而动（无家族背景）';
    final text = '${news.name}${news.description}';
    // 家族名/id 关键词都参与匹配（如「史塔克」「family_stark」）。
    String? hitKey;
    String? hitName;
    for (final otherFam in allFamilies) {
      if (otherFam.id == fam.id) continue;
      if (text.contains(otherFam.name) || text.contains(otherFam.id)) {
        hitKey = otherFam.id;
        hitName = otherFam.name;
        break;
      }
    }
    if (hitKey == null) return '牵涉此事的立场未明，谨慎观望';
    final relation = fam.relations[hitKey];
    if (relation == null) return '与${hitName}家族无明确恩怨，保持中立观察';
    if (relation > 20) return '与${hitName}家族友善（关系 $relation），可能站在其一边';
    if (relation < -20) return '与${hitName}家族敌对（关系 $relation），可能与其对立';
    return '与${hitName}家族关系平平（$relation），此事务必权衡';
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