# 架构

项目由三个边界清晰的部分组成：

- `collector/`：固定版本的 Veritas 上游源码、可复现补丁，以及独立 Rust 协议库。
- `protocol/`：版本化 JSON Schema 和跨语言测试夹具。
- `macos/HSRDamageMeter/`：Swift 6 原生客户端、领域模型、网络适配、本地历史和测试。

运行时数据流如下：

```text
Veritas xluau.dll（Wine 游戏进程）
  → loopback Socket.IO
  → VeritasClient
  → LiveCombatStore actor
  → 最高 10 Hz 的 SwiftUI 快照
  → SQLite 历史存储与 JSON 导出
```

Mac 客户端只连接本机回环地址，不读取进程内存，也不向游戏进程注入代码。网络层负责 Engine.IO/Socket.IO 传输和事件解码；领域层负责角色归属、伤害聚合、敌人状态及历史结算；UI 层只消费不可变快照。

`Networking/` 中的 v1 Envelope 模型和 `collector/` 的 Rust 协议库用于稳定、可测试的跨语言协议边界。当前 Veritas 兼容路径由 `VeritasNetworking/` 单独适配，因为上游 Socket.IO 数据不提供 v1 的序列号、时间戳和会话 UUID。

重要架构变更应记录在 `docs/adr/`，并同步更新协议 Schema、测试与相关文档。
