# HSR Damage Meter

面向在 Wine 中运行《崩坏：星穹铁道》的 Mac 用户：复用 Veritas 已解析的战斗数据，
通过 localhost WebSocket 交给原生 Swift macOS 客户端。

当前版本提供原生实时面板、三种浮窗、菜单栏状态、敌人信息、本地战斗历史与 JSON 导出。
从源码构建后打开 `dist/HSR Damage Meter.app`；设计来源与数据取舍见 [UI_REFERENCES](docs/UI_REFERENCES.md)。

2026-09-13 更新：已从现有 Veritas 0.2.52 Socket.IO 收到真实伤害事件；用户批准优先复用该接口。
现已交付 SwiftUI 实时面板、4.5.54 离线角色名称表，以及可复现的无 UI Collector 补丁。
游戏更新可能改变运行兼容性。见 [原生 App 使用](docs/NATIVE_APP.md)、[安装与回滚](docs/UI_ISOLATION_ACCEPTANCE.md)、[路线调整](docs/adr/0001-reuse-veritas-socketio.md) 与 [卡顿初诊](docs/PERFORMANCE_DIAGNOSIS.md)。
现有接口诊断：`python3 scripts/probe-veritas.py --seconds 10`。

## 架构与规范

Veritas → 非阻塞事件桥 → localhost WebSocket → Swift 解码 → CombatStore actor → 原生 UI。
Swift 客户端不接触游戏进程。工程与 UI 权威来源为 [CODEX_SPEC.md](CODEX_SPEC.md)。
现阶段交付五类事件的 JSON Schema、Rust/Swift 类型、共享样例及往返测试。

## Quickstart / Demo

需要 macOS 14+、Swift 6（Xcode Command Line Tools）、Rust 1.98.1、Python 3.10+。
在项目根目录执行：

```sh
python3 -m venv .tools/validation-venv
.tools/validation-venv/bin/python -m pip install -r scripts/requirements-validation.lock
./scripts/check.sh
```

Rust 使用标准 Cargo 或本机已配置的项目内隔离工具链；说明见 [开发指南](docs/DEVELOPMENT.md)。
不需要游戏即可运行协议 Demo：

```sh
./scripts/cargo.sh run --locked --bin fixture-roundtrip < protocol/fixtures/sample_session.jsonl
swift run --package-path macos/HSRDamageMeter fixture-roundtrip < protocol/fixtures/sample_session.jsonl
```

输出为标准化 JSONL（可空字段可能省略），其中包含用于精度测试的 Int64 最大值，**并非真实战斗记录**。

构建 macOS App：

```sh
./scripts/build-macos-app.sh
open 'dist/HSR Damage Meter.app'
```

Collector 安装脚本只接受显式游戏目录，且会在替换前验证哈希并确认游戏已经退出：

```sh
python3 scripts/install-collector.py no-ui-info --game-dir '/path/to/Honkai Star Rail'
```

## 许可与项目关系

M1 接入 Collector，M2–M3 网络与聚合，M4–M6 Live/Overlay/菜单栏，M7–M9 历史、分析、设置。
上游已固定为 hessiser/veritas 0.2.52，MIT 源码与许可证保留于 collector/upstream-veritas。
本项目采用 [GNU AGPL v3](LICENSE)。Vendored Veritas 仍适用其 MIT 许可证；角色资源来源仓库采用 AGPL-3.0。完整来源及例外见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

本项目是非官方社区工具，与 HoYoverse 无隶属、认可或赞助关系。《崩坏：星穹铁道》名称、角色和游戏素材的权利归其各自权利人所有。

贡献与安全问题分别参见 [CONTRIBUTING.md](CONTRIBUTING.md) 和 [SECURITY.md](SECURITY.md)。
