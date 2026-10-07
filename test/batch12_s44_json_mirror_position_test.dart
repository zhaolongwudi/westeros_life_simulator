/// S4-4（P1-01 终局）测试：锁定「assets/data 是只读镜像，不是运行时数据源」这一决策。
///
/// 【为什么要有这个测试】S4-4 是一次**决策**而非编码任务。`docs/02-roadmap.md` 的 M4
/// 原定完成态是「只改 `assets/data/events.json` 加新事件，不改一行 Dart，热重启即可触发」，
/// 该目标已于 2026-10-07 被正式放弃（理由见 `assets/data/README.md` 的 S4-4 决策段）：
/// 本作是离线单机 APK，无内容下载通道，JSON 即便打包也要重新构建安装才能生效，
/// 「改 JSON 免改代码」的收益为零，却会丢掉编译期校验——而本项目正反复栽在
/// 「键名/枚举/引用写错只有运行时才暴露」上（P1-03 的 10 种幽灵键、S3-1 的 5 个
/// 镜像不可反序列化 bug 都是实例）。
///
/// **风险**：决策只写在文档里，日后有人「顺手」补一行 `assets:` 并加个 `rootBundle`
/// 加载，就会进入**半迁移状态**——JSON 进了包却仍由 Dart 常量驱动，镜像与真相源
/// 双份数据同时存在，比现在更糟（这正是 P1-01 当初要修的病）。
/// 故用测试把「当前定位」钉住：**要改决策，必须同时改这个测试**，让改动显式发生。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 递归收集 [dir] 下所有 `.dart` 文件。
List<File> _dartFiles(String dir) {
  return Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
}

void main() {
  group('S4-4 · assets/data 定位为只读镜像', () {
    test('pubspec.yaml 不得声明 assets:', () {
      final text = File('pubspec.yaml').readAsStringSync();
      // 逐行判定，避免注释里的「assets」字样造成假失败。
      final offenders = <String>[];
      for (final line in text.split('\n')) {
        final stripped = line.split('#').first.trimRight();
        if (stripped.trimLeft().startsWith('assets:')) {
          offenders.add(line);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'S4-4 决策：JSON 不打包。若确实要外置，请先改 assets/data/README.md '
            '的决策段与 docs/03-审查接力.md 的 S4-4 记录，再删掉本断言。',
      );
    });

    test('lib/ 下不得出现运行时资产加载', () {
      const forbidden = <String>[
        'rootBundle',
        'AssetBundle',
        'DefaultAssetBundle',
      ];
      final hits = <String>[];
      for (final f in _dartFiles('lib')) {
        final src = f.readAsStringSync();
        for (final token in forbidden) {
          if (src.contains(token)) hits.add('${f.path}: $token');
        }
      }
      expect(
        hits,
        isEmpty,
        reason: 'S4-4 决策：运行时唯一数据源是 lib/data/*.dart 常量，'
            '不得从 assets 加载内容。命中：$hits',
      );
    });

    test('镜像声明文件存在且写明「不是运行时数据源」', () {
      final readme = File('assets/data/README.md');
      expect(readme.existsSync(), isTrue,
          reason: 'assets/data/README.md 是镜像定位的声明文件（S1-3 建立、S4-4 扩充）');
      final text = readme.readAsStringSync();
      expect(text, contains('不是运行时数据源'));
      expect(text, contains('S4-4'));
    });

    test('7 份镜像齐全（决策不等于可以删镜像）', () {
      const mirrors = <String>[
        'events.json',
        'families.json',
        'locations.json',
        'npcs.json',
        'systems.json',
        'items.json',
        'tasks.json',
      ];
      for (final name in mirrors) {
        expect(File('assets/data/$name').existsSync(), isTrue,
            reason: '镜像 $name 缺失——它是对账与反序列化往返的交叉验证工件，'
                '删掉会让 S3-1 那类「镜像不可反序列化」bug 重新失去抓手');
      }
    });
  });
}
