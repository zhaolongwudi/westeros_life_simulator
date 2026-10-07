/// Sprint 12 测试：OpenAI 兼容 BaseURL 归一化（S12-4）。
///
/// 【本批修的是什么】
/// `/v1` 拼接曾有 4 份重复实现（`ai_config.dart` / `ai_provider_defaults.dart` /
/// `settings_screen.dart` ×2），且都只认「恰好以 `/v1` 结尾」：
/// 用户最常见的粘贴形态 `https://x/v1/`（**带尾斜杠**）会被拼成 `https://x/v1//v1`
/// ⇒ 必然 404 ⇒ 用户报告「AI 怎么填都不可用」。
/// 现统一为单一函数 [normalizeOpenAiBaseUrl]。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:westeros_life_simulator/data/ai_provider_defaults.dart';

void main() {
  group('S12-4 normalizeOpenAiBaseUrl · 卡片要求的 5 种输入', () {
    const expected = 'https://api.example.com/v1';

    test('https://api.example.com（无斜杠无 /v1）', () {
      expect(normalizeOpenAiBaseUrl('https://api.example.com'), expected);
    });

    test('https://api.example.com/（尾斜杠）', () {
      expect(normalizeOpenAiBaseUrl('https://api.example.com/'), expected);
    });

    test('https://api.example.com/v1（已含）', () {
      expect(normalizeOpenAiBaseUrl('https://api.example.com/v1'), expected);
    });

    test('https://api.example.com/v1/（已含 + 尾斜杠）—— S11-2 用户实测形态',
        () {
      expect(normalizeOpenAiBaseUrl('https://api.example.com/v1/'), expected);
    });

    test('https://api.example.com/v1/chat/completions（直接粘完整端点）', () {
      expect(
        normalizeOpenAiBaseUrl('https://api.example.com/v1/chat/completions'),
        expected,
        reason: '应裁回 host+v1——本项目自己会拼 /chat/completions',
      );
    });
  });

  group('S12-4 其它边界', () {
    test('多个尾斜杠也收敛', () {
      expect(normalizeOpenAiBaseUrl('https://api.example.com/v1///'),
          'https://api.example.com/v1');
    });

    test('/models 端点也裁回 host', () {
      expect(normalizeOpenAiBaseUrl('https://api.example.com/v1/models'),
          'https://api.example.com/v1');
    });

    test('带端口的 host 正常', () {
      expect(normalizeOpenAiBaseUrl('http://127.0.0.1:11434'),
          'http://127.0.0.1:11434/v1');
    });

    test('不会重复补 /v1（幂等）', () {
      const once = 'https://api.example.com/v1';
      expect(normalizeOpenAiBaseUrl(normalizeOpenAiBaseUrl(once)), once);
    });

    test('host 里含 v1 但不是路径段（如 myv1host）不误判', () {
      expect(normalizeOpenAiBaseUrl('https://v1.example.com'),
          'https://v1.example.com/v1');
    });

    test('空串原样返回（不崩）', () {
      expect(normalizeOpenAiBaseUrl(''), '');
      expect(normalizeOpenAiBaseUrl('   '), '');
    });

    test('带空格的输入被 trim', () {
      expect(normalizeOpenAiBaseUrl('  https://api.example.com  '), expected);
    });
  });

  group('S12-4 预设的 chatBaseUrl 走同一函数', () {
    test('全部内置 provider 的 chatBaseUrl 都恰好一个 /v1 且无尾斜杠', () {
      for (final p in kAiProviderDefaults) {
        final url = p.chatBaseUrl;
        expect(url, isNot(endsWith('/')), reason: '${p.name} 不该有尾斜杠');
        expect(url.endsWith('/v1'), isTrue, reason: '${p.name}: $url');
        expect(url.contains('//v1'), isFalse, reason: '${p.name} 重复补了 /v1');
      }
    });
  });
}