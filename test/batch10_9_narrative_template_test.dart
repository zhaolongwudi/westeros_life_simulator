/// Batch 10-9 测试：叙事引导模板（身份 / 区域 / 季节差异化）。
///
/// 覆盖：
/// 1. 数据完整性：10 身份 / 12 区域 / 5 季节全部有叙事引导
/// 2. 引导内容非空且含关键语义（身份视角 / 区域底色 / 季节力量）
/// 3. prompt 注入：Dio mock 捕获请求体，验证身份中文标签 + 叙事引导注入
/// 4. 兜底分支：未知身份/区域/季节返回默认引导
library;
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/narrative_templates.dart';
import 'package:westeros_life_simulator/models/event.dart';
import 'package:westeros_life_simulator/models/player.dart';
import 'package:westeros_life_simulator/services/ai_service.dart';

void main() {
  group('Batch 10-9 数据完整性', () {
    test('10 种身份全部有非空叙事引导', () {
      for (final identity in PlayerIdentity.values) {
        final guide = identityNarrativeGuide(identity);
        expect(guide.isNotEmpty, true,
            reason: '身份 ${identity.name} 缺失叙事引导');
        expect(guide.length, greaterThan(20),
            reason: '身份 ${identity.name} 引导过短');
      }
    });

    test('12 个区域全部有非空叙事引导', () {
      const regions = <String>[
        '北境', '河间地', '谷地', '西境', '河湾地', '王领',
        '风暴地', '多恩', '铁群岛', '厄索斯', '超自然', '未知世界',
      ];
      for (final region in regions) {
        final guide = regionNarrativeGuide(region);
        expect(guide.isNotEmpty, true, reason: '区域 $region 缺失叙事引导');
        expect(guide.length, greaterThan(10), reason: '区域 $region 引导过短');
      }
    });

    test('5 个季节全部有非空叙事引导', () {
      const seasons = <String>['spring', 'summer', 'autumn', 'winter', 'longwinter'];
      for (final season in seasons) {
        final guide = seasonNarrativeGuide(season);
        expect(guide.isNotEmpty, true, reason: '季节 $season 缺失叙事引导');
        expect(guide.length, greaterThan(10), reason: '季节 $season 引导过短');
      }
    });

    test('身份引导各不相同（差异化）', () {
      final guides = PlayerIdentity.values
          .map(identityNarrativeGuide)
          .toSet();
      expect(guides.length, PlayerIdentity.values.length,
          reason: '存在重复的身份引导');
    });
  });

  group('Batch 10-9 兜底分支', () {
    test('未知区域返回默认引导', () {
      final guide = regionNarrativeGuide('不存在之地');
      expect(guide, contains('这片土地'));
    });

    test('未知季节返回默认引导', () {
      final guide = seasonNarrativeGuide('unknown');
      expect(guide, contains('季节更替'));
    });
  });

  group('Batch 10-9 prompt 注入', () {
    // 注意：必须用 List<String?> 可变容器捕获请求体，不能直接返回 String? record——
    // record 解构是值拷贝，onRequest 闭包修改的是函数内部变量而非解构后的变量，
    // 会导致 captured 永远读不到更新值（CI 实测 captured = null）。
    (List<String?>, Dio) _captureDio() {
      final captured = <String?>[null];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured[0] = options.data.toString();
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'choices': <dynamic>[
                    <String, dynamic>{
                      'message': <String, dynamic>{
                        'content': '{"narrative":"测试叙事","choices":[]}',
                      },
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      return (captured, dio);
    }

    test('提示词注入身份中文标签与身份叙事引导', () async {
      final (capturedBox, dio) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final player = Player.defaultPlayer().copyWith(
        identity: PlayerIdentity.merchant,
        locationId: 'location_kings_landing',
      );
      await service.generateNarrative(
        player: player,
        context: '你在集市上。',
        availableEvents: const <GameEvent>[],
        season: 'summer',
        maxRetries: 0,
      );
      final captured = capturedBox[0];
      expect(captured, isNotNull);
      expect(captured, contains('身份：商人'));
      expect(captured, contains('叙事引导（身份）'));
      expect(captured, contains('金币即权力'));
    });

    test('提示词注入区域与季节叙事引导', () async {
      final (capturedBox, dio) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      final player = Player.defaultPlayer().copyWith(
        locationId: 'location_winterfell', // 北境
      );
      await service.generateNarrative(
        player: player,
        context: '你在临冬城。',
        availableEvents: const <GameEvent>[],
        season: 'winter',
        maxRetries: 0,
      );
      final captured = capturedBox[0];
      expect(captured, isNotNull);
      expect(captured, contains('叙事引导（区域）'));
      expect(captured, contains('北境'));
      expect(captured, contains('凛冬将至'));
      expect(captured, contains('叙事引导（季节）'));
      expect(captured, contains('严冬已至'));
    });

    test('prompt 保留既有身份字段（中文标签替换英文枚举名）', () async {
      final (capturedBox, dio) = _captureDio();
      final service = AiService(
        apiKey: 'test_key',
        dio: dio,
        baseUrl: 'https://mock.example.com/v1',
      );
      // 默认玩家是贵族 noble
      final player = Player.defaultPlayer();
      await service.generateNarrative(
        player: player,
        context: '你在城堡里。',
        availableEvents: const <GameEvent>[],
        season: 'spring',
        maxRetries: 0,
      );
      final captured = capturedBox[0];
      expect(captured, isNotNull);
      expect(captured, contains('身份：贵族'));
      // 不再输出英文枚举名
      expect(captured, isNot(contains('身份：noble')));
      expect(captured, contains('叙事引导（身份）'));
    });
  });
}