# Protocol v1

规范入口：[`../docs/IPC_PROTOCOL.md`](../docs/IPC_PROTOCOL.md)。
Schema 使用 JSON Schema Draft 2020-12；`envelope.schema.json` 为消息校验入口，按 `type` 引用 payload 定义。
`action.schema.json` 明确拒绝所有值，仅标记未来扩展，不代表已支持 action 事件。

共享样例：`fixtures/sample_session.jsonl` 覆盖所有五类 MVP 事件、未知字段、零伤害和 Int64 上限；
`sample_damage.json` 为单条完整消息；`invalid_events.json` 为两端共用的拒绝样例。
在根目录运行 `./scripts/check.sh` 同时验证 Schema 和双向序列化。
