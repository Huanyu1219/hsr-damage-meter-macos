# 架构

权威依据：CODEX_SPEC.md 第 0–11、44–47 节。

- collector：独立 Rust 协议库与 EventPublisher trait；upstream-veritas 当前仅占位。
- protocol：版本化 JSON 边界与共用 fixtures，不导入任一端内部结构。
- macos/HSRDamageMeter：Swift 6 协议库、命令行验证工具、测试与未来功能目录。
- scripts：本地验收；docs：协议、开发与上游变更记录。

M0 用 Swift Package 使协议模型可编译/测试，M2 创建实际 Xcode App 工程。
不创建伪造的空 xcodeproj，也不提前实现网络、UI、CombatStore 或 SQLite。

后续数据流：Collector worker → URLSessionWebSocketTask → EventDecoder → CombatStore actor
→ 最高 10–20 Hz UI 快照；完成会话通过 GRDB/SQLite 持久化。Swift 不读进程内存、不注入 Wine、不修改游戏。
