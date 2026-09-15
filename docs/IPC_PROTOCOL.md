# IPC v1 契约

本规范定义跨语言 v1 线协议及传输约束。当前 Veritas Socket.IO 兼容层使用独立适配器，差异见 ADR 0001。

- 每个 WebSocket 文本帧是一条 JSON 消息；JSONL 仅用于样例/命令行工具。
- 默认地址 `ws://127.0.0.1:13051`，端口可配置，仅允许 loopback，无 MVP 鉴权。
- 必须存在 `protocolVersion`、`type`、`sequence`、`timestamp`、`payload`。
- v1 只接收 hello、combat_start、combat_end、party_update、damage；未知版本/事件显式报错。
- 同一版本允许增加字段；当前模型忽略未知键，重新编码不保留未知键。
- sequence 为 1…Int64.max；进程生命周期内严格递增，跨战斗不重置。缺号允许，重复/倒序不能被误算。
  解码器本身无状态；顺序检查由连接状态机负责。进程重启重新 hello 并允许新序列。
- timestamp 是非负、有限的 Unix epoch 秒（可带小数），不是单调时钟，不用于判断事件顺序。
- 所有整数使用 JSON 整数，ID 与 amount 均为 0…Int64.max。不得经 Double 或 JavaScript Number 中转。
- sessionId 必须为标准带连字符 UUID 字符串。身份使用实体/角色 ID，不使用显示名。

| type | 必填 payload | 可空或可省略 |
| --- | --- | --- |
| hello | collector、collectorVersion、gameVersion、capabilities（字符串数组） | 无；未知 gameVersion 使用规范指定的 unknown |
| combat_start | sessionId | 无 |
| combat_end | sessionId | reason |
| party_update | members 数组；每项 entityId | 每项 characterId、name |
| damage | sessionId、amount | sourceEntityId、sourceCharacterId、targetEntityId、skillId、damageType、isCrit |

`null` 与省略等价；未知暴击不是 false，未知角色不填虚假 ID。damageType 是开放字符串（允许 unknown），
不得虚构元素、技能分类或归属。无法提供 amount/sessionId 时不能发布可聚合 damage，应记录诊断。
party_update 视为当前队伍完整快照，空数组有效；具体来源映射必须对照上游事件验证。

Collector 桥的 `try_publish(Event)` 只投递轻量数据到有界队列，返回 QueueFull/Closed 表示未接收。
单一 worker 为实际发布消息分配全局序列和时间，负责 JSON 与网络。游戏回调不能等待网络或慢客户端。
实现必须定义溢出诊断与会话不完整处理，不得悄悄丢事件后宣称总伤害准确。协议不承诺重放。
连接 hello、断线、重连和多客户端排序必须由集成测试验证。

验证入口：`./scripts/check.sh`。Rust 与 Swift 都读取同一组合法/非法 fixture，
脚本检查 Swift→Rust 和 Rust→Swift 的语义等价及输出 Schema，有意将可空键与缺省统一比较。
