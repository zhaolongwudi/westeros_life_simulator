# assets/data — 只读导出镜像

本目录下的 7 份 JSON **不是运行时数据源**，而是 `lib/data/*.dart` 的单向导出镜像。

- 生成方式：`python3 scripts/dart_content_extract.py`
- 校验方式：`python3 scripts/check_content_sync.py`
- `pubspec.yaml` **未声明 assets**，这 7 份文件不会被打进 APK，**运行时从不加载它们**。

因此：

1. **改这里的 JSON 不会改变任何游戏行为**。要改内容，请改 `lib/data/*.dart`。
2. 改动 `lib/data/*.dart` 后**必须**重跑导出脚本再提交，否则对账脚本（CI 会跑）会失败。
3. 想让 JSON 变成真正可热更的数据源（M4 原定目标），需要：
   - 在 `pubspec.yaml` 补 `assets:` 声明；
   - data 层改为 `rootBundle` 加载；
   - 先补齐 `Npc.fromJson` 等模型的契约测试（见 `docs/03-审查接力.md` 的 S4-4）。

详见 `docs/03-审查接力.md` 的 P1-01 / S1-3。
