# M0 验收记录

M0 已完成并停止。用户最新方向：优先打通 DLL 在 Wine 中加载、导出数据、Mac App 接收显示的最小链路。
复杂 UI、历史、分析和持久化暂缓。

## 验收

- Swift 6.4 / macOS 本机：6 项 XCTest 通过。
- Rust 1.98.1：6 项集成测试通过。
- 7 个 Schema 自检；7 条会话消息与单条 damage 校验通过。
- 24 个非法输入由 Schema、Rust、Swift 一致拒绝。
- Rust→Swift 与 Swift→Rust 往返、Int64.max 精度、null/缺省语义一致。
- 原始规范逐字节复制为 CODEX_SPEC.md；未改写用户规范。
- 本地 Git main 已初始化，尚无提交或远程；未改动上游，无应用/网络运行验收。

复现：项目根目录运行 `./scripts/check.sh`。依赖准备见 DEVELOPMENT.md。

## 协议决定与假设

v1 五事件、版本强校验；可空观察值不虚构；必填 sessionId/amount；Int64 非负伤害及 ID；
时间为 epoch 秒，序列为进程内递增整数。未知附加键允许但往返不保留；未知事件显式拒绝。
party_update 暂定义为完整快照，须在 M1 核对上游。序列、慢客户端与溢出策略属于 M1 的运行时验收。
详细字段与兼容性契约见 IPC_PROTOCOL.md。

M0 的 Rust 是独立协议库，不是可加载 DLL；Swift Package 是协议验证入口，不是最终 App。
上游仓库、许可、游戏/Wine 兼容性尚未验证。LICENSE 待确认，不对未引入的 Veritas 推定许可。

## M1 的准确下一步

1. 确认 Veritas 官方仓库、固定 revision、许可及当前 Wine 产品/版本。
2. 阅读其真实加载流程，验证 DLL 如何被游戏加载；仅放入目录不能视为已经加载。
3. 找到现有已解析 session/party/damage 事件的最窄观察点，保留原 UI 和行为。
4. 实现有界非阻塞队列、worker 编码与 127.0.0.1 WebSocket publisher。
5. 验证五事件、序列/会话、慢客户端隔离及数据完整性；记录每项上游补丁。

## 文件清单

更新已有 AGENTS.md、.project-state.json；其余为新增（功能预留目录仅有 .gitkeep）。

- `.env.example`
- `.gitignore`
- `.project-state.json`
- `AGENTS.md`
- `CODEX_SPEC.md`
- `README.md`
- `collector/Cargo.lock`
- `collector/Cargo.toml`
- `collector/README.md`
- `collector/src/bin/fixture-roundtrip.rs`
- `collector/src/bridge/event_publisher.rs`
- `collector/src/bridge/mod.rs`
- `collector/src/bridge/payloads.rs`
- `collector/src/bridge/protocol.rs`
- `collector/src/lib.rs`
- `collector/tests/protocol.rs`
- `collector/upstream-veritas/README.md`
- `docs/ARCHITECTURE.md`
- `docs/DEVELOPMENT.md`
- `docs/IPC_PROTOCOL.md`
- `docs/UI_SPEC.md`
- `docs/VERITAS_PATCHES.md`
- `macos/HSRDamageMeter/App/.gitkeep`
- `macos/HSRDamageMeter/DesignSystem/Components/.gitkeep`
- `macos/HSRDamageMeter/DesignSystem/Tokens/.gitkeep`
- `macos/HSRDamageMeter/Domain/.gitkeep`
- `macos/HSRDamageMeter/Features/Analysis/.gitkeep`
- `macos/HSRDamageMeter/Features/History/.gitkeep`
- `macos/HSRDamageMeter/Features/Live/.gitkeep`
- `macos/HSRDamageMeter/Features/Settings/.gitkeep`
- `macos/HSRDamageMeter/MenuBar/.gitkeep`
- `macos/HSRDamageMeter/Networking/ProtocolEnvelope.swift`
- `macos/HSRDamageMeter/Networking/ProtocolEvent.swift`
- `macos/HSRDamageMeter/Networking/ProtocolPayloads.swift`
- `macos/HSRDamageMeter/Overlay/.gitkeep`
- `macos/HSRDamageMeter/Package.swift`
- `macos/HSRDamageMeter/PreviewData/.gitkeep`
- `macos/HSRDamageMeter/Storage/.gitkeep`
- `macos/HSRDamageMeter/Tests/ProtocolTests.swift`
- `macos/HSRDamageMeter/Tools/FixtureRoundtrip/main.swift`
- `protocol/README.md`
- `protocol/fixtures/invalid_events.json`
- `protocol/fixtures/sample_damage.json`
- `protocol/fixtures/sample_session.jsonl`
- `protocol/schema/action.schema.json`
- `protocol/schema/damage.schema.json`
- `protocol/schema/envelope.schema.json`
- `protocol/schema/hello.schema.json`
- `protocol/schema/party.schema.json`
- `protocol/schema/session.schema.json`
- `rust-toolchain.toml`
- `scripts/cargo.sh`
- `scripts/check.sh`
- `scripts/requirements-validation.lock`
- `scripts/validate-fixtures.py`
- `docs/M0_REPORT.md`
