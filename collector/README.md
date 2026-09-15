# Collector protocol bridge

本目录包含 Rust 协议类型与非阻塞 `EventPublisher` 接口，不包含实际游戏集成或服务器。
`src/bridge/protocol.rs` 提供 `Envelope::new`、`validate`、`to_json` 及 serde 解码。
外部边界使用 Envelope 校验，不直接将裸 payload 视为完整有效消息。

在根目录运行 `./scripts/cargo.sh test --locked`。上游接入和补丁说明见 `../docs/VERITAS_PATCHES.md`。
