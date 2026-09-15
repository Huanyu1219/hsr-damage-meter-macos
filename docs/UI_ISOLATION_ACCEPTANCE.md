# 原生 UI 与 Collector 无浮窗对照交付

## 当前交付

- `dist/HSR Damage Meter.app`：Swift 6 / SwiftUI 原生 App，已 ad-hoc 签名并通过签名验证。
- `dist/collector-no-ui/xluau.dll`：固定 0.2.52 源码，仅应用 0002，跳过 overlay::initialize。
- `dist/collector-control/xluau.dll`：同一 Rust/Clang/MinGW 工具链编译的原始源码对照。
- `dist/collector-manifest.json`：各 DLL 路径、SHA-256、源码 revision 和工具链。
- `backups/collector/`：原始官方 DLL 的校验备份，已验证内容一致。
- `collector/upstream-veritas/`：原样导入 MIT 上游 0.2.52 源码与锁文件，来源见 collector/UPSTREAM.json。
- 本地 Nanoka 4.5.54 角色 JSON：98 项，资源来源和 SHA-256 已记录；本轮仅名称映射，不含完整技能库/头像。

## 已执行验证

- Rust 原 M0 测试 6 项；Swift 原协议测试 6 项、实时聚合/解码测试 5 项。
- 独立 localhost WebSocket mock 联调 1 项：实际 URLSession 握手、namespace、心跳、精确累计和结算通过。
- 原生窗口视觉检查：指标卡、排行、中文名、比例；重置确认及重置空状态；mock 断开后显示 Collector 未连接。
- mock 已停止，1305 端口已释放，测试统计已清空；App 最终状态为离线等待。
- 全套 M0 Schema/跨语言检查通过；SwiftPM 资源 hash 与 App 签名通过。
- 两个 DLL Windows x86-64 release 构建通过（上游仍有未使用代码等 warning）。
- 无 UI DLL 在隔离 `.tools/wine-smoke` Wine prefix 通过 LoadLibrary 检查，日志记录 LOAD_OK。
  **这只验证导入依赖和加载，不证明在真实游戏中采集成功或帧时间改善。**
- 游戏停止后安装 no-ui，安装前后 SHA-256 核对；原版备份完整。没有同时应用日志补丁。

## 现在如何验证

1. 保持 Mac App 运行，正常用 YAAGL 启动游戏。
2. 游戏内原 Veritas 窗口应不再出现。日志应有 `Native UI build: in-game overlay initialization disabled`。
3. Mac 面板应显示 Collector 已连接；从新战斗开始观察角色伤害、总伤害和最高单次。
4. 对比相同场景、角色、技能、画质，先热身一次再比较卡顿。4.5 兼容性仍未验证。
5. 若移除 UI 仍卡，再独立测试日志级别；不要把未解决的兼容错误误归因为 UI。

## 切换与回滚

必须先退出游戏；脚本发现 StarRail 运行会拒绝替换。

```sh
# 切到同工具链、有原 UI 的对照版
python3 scripts/install-collector.py control
# 切回无 UI 版
python3 scripts/install-collector.py no-ui
# 恢复下载的官方原版
python3 scripts/install-collector.py original
```

安装器只接受当前清单或已知原版 SHA，验证备份后在游戏目录同盘暂存并原子替换。
原版 SHA：`d0bd2287b7b30f962a7a208c090bbe0ba2cff06e16dbc16ec1071821ea7667b2`。

## 构建复现

Mac：`./scripts/build-macos-app.sh`。
Collector：先安装 Homebrew mingw-w64、项目内 rustup nightly-2025-05-17 及 x86_64-pc-windows-gnu target，
再运行 `./scripts/build-collector.sh no-ui` 或 `control`。脚本使用两线程与独立构建 staging。
工具链依赖为本机 Apple Clang + MinGW；区别于上游 Windows MSVC，故提供同工具链对照 DLL。
候选 DLL 重建后需重新生成并核验 manifest，再通过安装器部署，防止误装未知文件。

原 UI 的源文件/依赖保留以便上游对照，运行时不初始化其绘制处理；并非所有 UI 相关依赖都从二进制移除。
本轮不修改 IL2CPP 采集路径、不绕过防护、不声称修复 4.5 解析问题。

## 首次真实战斗反馈

用户确认 Mac 面板已显示真实伤害，但游戏仍卡顿。已核对运行中的 DLL SHA 与 no-ui 一致，
15:25:54 日志明确记录 `Native UI build: in-game overlay initialization disabled`。
此后 debug 日志采样为 119,974 行 / 12,113,076 bytes，仍主要是字段/方法解析。
因此本轮 UI 隔离成功，但没有解决卡顿；不能将 native UI 当作性能修复。
下一轮只在 no-ui 基础上应用 0001 日志级别补丁。游戏仍在运行，尚未构建/安装该组合，已请用户先退出。

## 第二轮：无 UI + Info 日志

用户确认退出游戏后，构建 no-ui-info（仅在 no-ui 基础上应用0001）。
同一工具链 release成功、隔离Wine LOAD_OK，安装器备份上一no-ui版本后完成替换。
当前安装版本为 no-ui-info，真实战斗性能改善待用户反馈。

```sh
# 退出游戏后恢复上一轮，仅无UI、仍保留Debug日志的版本
python3 scripts/install-collector.py no-ui
# 切到本轮版本
python3 scripts/install-collector.py no-ui-info
# 恢复官方下载版
python3 scripts/install-collector.py original
```

Info/Warn/Error仍写日志，veritas.debug.log文件仍可能存在并包含Info以上内容；
验收指标是没有DEBG/Trace高频输出，而不是文件必须消失。
