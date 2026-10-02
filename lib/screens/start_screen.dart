/// 开局选择界面：身份/家族/出生地/时代/季节选择，生成角色进入游戏。
///
/// 参考 docs/08_玩法设计.md「玩法开始」。
/// 角色生成逻辑抽为纯函数（buildSetupPlayer/buildSetupProgress），便于测试。
library;

import 'package:flutter/material.dart';

import '../data/family_data.dart';
import '../data/location_data.dart';
import '../game_engine.dart';
import '../models/location.dart';
import '../models/player.dart';
import '../providers/game_state_provider.dart';
import '../theme/westeros_theme.dart';
import '../utils/labels.dart';
import '../widgets/theme/ornate.dart';
import 'game_screen.dart';

/// 开局配置。
class GameSetup {
  const GameSetup({
    required this.name,
    required this.gender,
    required this.identity,
    required this.familyId,
    required this.locationId,
    required this.era,
    required this.season,
    required this.year,
    required this.month,
  });

  final String name;
  final String gender;
  final PlayerIdentity identity;

  /// 家族 ID；'none' 表示自由民（无家族）。
  final String familyId;
  final String locationId;

  /// 时代（中文，如 '篡夺者战争后'）。
  final String era;

  /// 季节标识（spring/summer/autumn/winter/longwinter）。
  final String season;
  final int year;
  final int month;
}

/// 时代选项（中文名 -> (年份, 描述)）。
const Map<String, (int, String)> kEras = <String, (int, String)>{
  '篡夺者战争前': (281, '劳勃叛乱爆发前夕，大陆暗流涌动。'),
  '篡夺者战争期间': (282, '战火正酣，各方势力站队。'),
  '篡夺者战争后': (283, '劳勃加冕，坦格利安流亡。'),
  '当前时代': (298, '权力的游戏拉开帷幕。'),
};

/// 季节选项（标识 -> 月份）。
const Map<String, int> kSeasons = <String, int>{
  'spring': 3,
  'summer': 6,
  'autumn': 9,
  'winter': 12,
  'longwinter': 12,
};

/// 根据开局配置构建玩家。
Player buildSetupPlayer(GameSetup setup) {
  final isNoble = setup.identity == PlayerIdentity.noble ||
      setup.identity == PlayerIdentity.soldier;
  // 初始资金：贵族/士兵 120，商人 150，平民 40，其余 80
  final gold = switch (setup.identity) {
    PlayerIdentity.merchant => 150,
    PlayerIdentity.commoner => 40,
    PlayerIdentity.noble || PlayerIdentity.soldier => 120,
    _ => 80,
  };
  final skills = <String, int>{
    'sword': setup.identity == PlayerIdentity.soldier ? 4 : 2,
    'archery': setup.identity == PlayerIdentity.soldier ? 3 : 2,
    'riding': setup.identity == PlayerIdentity.noble ? 4 : 2,
    'speech': setup.identity == PlayerIdentity.merchant ||
            setup.identity == PlayerIdentity.priest ||
            setup.identity == PlayerIdentity.scholar ||
            setup.identity == PlayerIdentity.maester
        ? 4
        : 2,
    'alchemy': setup.identity == PlayerIdentity.maester ? 3 : 0,
  };
  return Player(
    id: 'player_${DateTime.now().millisecondsSinceEpoch}',
    name: setup.name,
    identity: setup.identity,
    familyId: setup.familyId,
    age: 18,
    gender: setup.gender,
    locationId: setup.locationId,
    gold: gold,
    reputation: isNoble ? 50 : 30,
    skills: skills,
    attributes: const <String, int>{
      'strength': 5,
      'agility': 5,
      'intelligence': 5,
      'charisma': 5,
      'willpower': 5,
      'perception': 5,
    },
    inventory: const <String>[],
    relations: const <String, int>{},
    flags: const <String, bool>{
      'isAlive': true,
      'isMarried': false,
      'isExiled': false,
    },
    // 开局状态：满血满精力，饱食 60（不会立刻饿死，但需要尽早觅食）
    health: 100,
    energy: 100,
    hunger: 60,
  );
}

/// 根据开局配置构建游戏进度。
GameProgress buildSetupProgress(GameSetup setup) {
  return GameProgress(
    year: setup.year,
    month: setup.month,
    season: setup.season,
    era: setup.era,
    turnCount: 0,
  );
}

/// 开局选择界面。
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _gender = 'male';
  PlayerIdentity _identity = PlayerIdentity.noble;
  String _familyId = 'family_stark';
  String _locationId = 'location_winterfell';
  String _era = '篡夺者战争后';
  String _season = 'spring';

  /// 随机名字池。
  static const List<String> _namePool = <String>[
    '艾德温', '布兰登', '凯特琳', '梅丽珊卓', '奥利弗', '亚拉',
    '琼恩', '戴伦', '珊莎', '提利昂', '奥柏伦', '莱安娜',
  ];

  /// 随机生成名字。
  void _randomName() {
    final rnd = DateTime.now().millisecondsSinceEpoch % _namePool.length;
    _nameController.text = _namePool[rnd];
  }

  /// 家族 seat 作为默认出生地。
  void _applyFamilySeat(String familyId) {
    for (final f in allFamilies) {
      if (f.id == familyId) {
        setState(() => _locationId = f.seat);
        return;
      }
    }
  }

  /// 开始游戏。
  void _startGame() {
    final name = _nameController.text.trim().isEmpty
        ? _namePool[DateTime.now().millisecondsSinceEpoch % _namePool.length]
        : _nameController.text.trim();
    final setup = GameSetup(
      name: name,
      gender: _gender,
      identity: _identity,
      familyId: _familyId,
      locationId: _locationId,
      era: _era,
      season: _season,
      year: kEras[_era]!.$1,
      month: kSeasons[_season]!,
    );
    final player = buildSetupPlayer(setup);
    final progress = buildSetupProgress(setup);
    final engine = GameEngine(
      player: player,
      progress: progress,
      isGameActive: true,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameScreen(engine: engine)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('开始新人生')),
      body: ParchmentBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // ── 开篇饰头 ──
            const _StartHero(),
            const SizedBox(height: 16),
            // 姓名 + 性别
            GildedCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.badge_outlined, title: '姓名'),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: '输入姓名（留空随机）',
                            prefixIcon: Icon(Icons.edit_outlined, size: 18),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.casino_outlined),
                        tooltip: '随机名字',
                        onPressed: _randomName,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const OrnateHeader(icon: Icons.wc_outlined, title: '性别'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(value: 'male', label: Text('男')),
                      ButtonSegment<String>(value: 'female', label: Text('女')),
                    ],
                    selected: <String>{_gender},
                    onSelectionChanged: (s) =>
                        setState(() => _gender = s.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 身份
            GildedCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.emoji_people_outlined, title: '身份'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: PlayerIdentity.values.map((id) {
                      return ChoiceChip(
                        label: Text(identityLabel(id)),
                        selected: _identity == id,
                        onSelected: (_) => setState(() => _identity = id),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 家族
            GildedCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.shield_outlined, title: '家族'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      ChoiceChip(
                        label: const Text('自由民'),
                        selected: _familyId == 'none',
                        onSelected: (_) => setState(() => _familyId = 'none'),
                      ),
                      for (final fam in allFamilies)
                        ChoiceChip(
                          label: Text(fam.name),
                          selected: _familyId == fam.id,
                          onSelected: (_) {
                            setState(() => _familyId = fam.id);
                            _applyFamilySeat(fam.id);
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 出生地
            GildedCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.place_outlined, title: '出生地'),
                  const SizedBox(height: 4),
                  Text(
                    _locationLabel(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  // 按区域分组的地点选择
                  for (final region in _regions())
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Text(
                            region,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _locationsIn(region).map((loc) {
                            return ChoiceChip(
                              label: Text(loc.name),
                              selected: _locationId == loc.id,
                              onSelected: (_) =>
                                  setState(() => _locationId = loc.id),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 时代
            GildedCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.hourglass_empty, title: '时代'),
                  const SizedBox(height: 8),
                  for (final entry in kEras.entries)
                    RadioListTile<String>(
                      title: Text(entry.key),
                      subtitle: Text(entry.value.$2),
                      value: entry.key,
                      groupValue: _era,
                      dense: true,
                      onChanged: (v) =>
                          setState(() => _era = v ?? _era),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 季节
            GildedCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const OrnateHeader(icon: Icons.cloud_outlined, title: '出生季节'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: kSeasons.keys.map((s) {
                      return ChoiceChip(
                        label: Text(seasonLabel(s)),
                        selected: _season == s,
                        onSelected: (_) => setState(() => _season = s),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 开始按钮
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: Text('开始游戏（${_nameController.text.trim().isEmpty ? '随机姓名' : _nameController.text.trim()}）'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: WesterosColors.gold,
                foregroundColor: WesterosColors.barkDeep,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: WesterosColors.goldBright, width: 1.2),
                ),
              ),
              onPressed: _startGame,
            ),
            const SizedBox(height: 8),
            // 底部装饰
            const Center(
              child: Text(
                '❖ 铁与火 · 冰与土之歌 ❖',
                style: TextStyle(color: WesterosColors.inkDim, fontSize: 12, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 当前出生地标签。
  String _locationLabel() {
    for (final l in allLocations) {
      if (l.id == _locationId) return '${l.name}（${l.region}）';
    }
    return _locationId;
  }

  /// 全部区域（有序去重）。
  List<String> _regions() {
    final seen = <String>{};
    final result = <String>[];
    for (final loc in allLocations) {
      if (seen.add(loc.region)) result.add(loc.region);
    }
    return result;
  }

  /// 指定区域的地点。
  List<Location> _locationsIn(String region) {
    return allLocations.where((l) => l.region == region).toList();
  }
}

/// 开篇饰头：铁王座主题头图 + 副标题。
class _StartHero extends StatelessWidget {
  const _StartHero();

  @override
  Widget build(BuildContext context) {
    return GildedCard(
      highlight: true,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      child: Column(
        children: <Widget>[
          // 双剑交叉 + 王冠
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.flag_outlined, size: 22, color: WesterosColors.steel),
              SizedBox(width: 14),
              Icon(Icons.crown_outlined, size: 34, color: WesterosColors.goldBright),
              SizedBox(width: 14),
              Icon(Icons.local_fire_department_outlined, size: 22, color: WesterosColors.bloodRed),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '维斯特洛人生模拟器',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontFamily: 'serif',
                  color: WesterosColors.goldBright,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 6),
          const WesterosDivider(),
          const SizedBox(height: 8),
          const Text(
            '凛冬将至，写下你的人生篇章',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: WesterosColors.inkDim,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}