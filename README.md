# HSR Damage Meter for macOS

为在 Wine 中运行《崩坏：星穹铁道》的 Mac 玩家设计的本地伤害统计工具。

通过接入开源 Veritas 解析的战斗数据（WebSocket），在 Mac 上提供原生实时伤害面板、浮窗、菜单栏状态显示、敌人信息追踪和本地战斗历史导出。

## 特性

- **原生 macOS 设计** —— 使用 SwiftUI，与系统视觉风格一致
- **实时伤害显示** —— 接收 Veritas 解析的战斗事件，零延迟更新
- **灵活的显示方案** —— 可选主窗口、浮窗模式、菜单栏状态
- **战斗历史** —— 本地存储每场战斗的数据，支持 JSON 导出
- **游戏隔离** —— Swift 客户端完全独立，不触及游戏进程
- **离线可测试** —— 无需游戏即可验证协议和数据流

## 快速开始

### 环境要求

- macOS 14 或更新版本
- Swift 6（Xcode Command Line Tools）
- Rust 1.98.1+
- Python 3.10+

### 构建应用

在项目根目录运行：

```sh
./scripts/build-macos-app.sh
open 'dist/HSR Damage Meter.app'
```

### 验证开发环境

```sh
python3 -m venv .tools/validation-venv
.tools/validation-venv/bin/python -m pip install -r scripts/requirements-validation.lock
./scripts/check.sh
```

### 测试协议数据流（无需游戏）

```sh
# Rust 示例
./scripts/cargo.sh run --locked --bin fixture-roundtrip < protocol/fixtures/sample_session.jsonl

# Swift 示例
swift run --package-path macos/HSRDamageMeter fixture-roundtrip < protocol/fixtures/sample_session.jsonl
```

输出为标准化 JSONL 格式，包含压力测试数据（Int64 最大值等），**不代表真实战斗**。

## 安装收集器

如果要从 Wine 中的游戏接收实时数据，安装对应的 Collector 补丁：

```sh
python3 scripts/install-collector.py no-ui-info --game-dir '/path/to/Honkai Star Rail'
```

脚本会验证哈希、确认游戏已退出后再替换文件。详见 [安装与回滚说明](docs/UI_ISOLATION_ACCEPTANCE.md)。

## 架构概览

```
Veritas（游戏数据解析）
    ↓
Rust 协议桥（非阻塞事件）
    ↓
localhost WebSocket
    ↓
Swift 客户端（解码 + CombatStore actor）
    ↓
原生 macOS UI
```

- **Collector** 模块：Rust 协议定义与事件校验
- **Swift App**：macOS 图形界面与本地存储
- **Protocol**：共享 JSON Schema 与测试夹具

## 文档导航

- [开发指南](docs/DEVELOPMENT.md) —— 工具链、编译选项、调试
- [IPC 协议规范](docs/IPC_PROTOCOL.md) —— 消息格式与事件类型
- [原生应用使用](docs/NATIVE_APP.md) —— 功能说明与常见问题
- [项目规范](CODEX_SPEC.md) —— 工程要求与 UI 设计约束
- [技术决策](docs/adr/) —— 为什么选择复用 Veritas、为什么需要无 UI 补丁

## 许可与致谢

本项目采用 **GNU AGPL v3**（见 [LICENSE](LICENSE)）。

**特别感谢：**
- [hessiser/veritas](https://github.com/hessiser/veritas) —— 开源游戏数据解析器（MIT 许可，代码保留在 `collector/upstream-veritas`）
- 角色名称与资源来自社区数据仓库

完整第三方许可清单见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

### 免责声明

本项目是非官方社区工具，与 HoYoverse 无隶属、认可或赞助关系。《崩坏：星穹铁道》名称、角色和游戏素材的权利归其各自权利人所有。

## 贡献与反馈

欢迎报告问题、建议功能或提交代码。详见：

- [CONTRIBUTING.md](CONTRIBUTING.md) —— 贡献指南与 PR 流程
- [SECURITY.md](SECURITY.md) —— 安全漏洞报告渠道
