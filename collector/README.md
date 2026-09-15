# Collector bridge — M0

当前仅包含 Rust 协议类型与非阻塞 `EventPublisher` 接口，无实际游戏集成或服务器。
`src/bridge/protocol.rs` 提供 `Envelope::new`、`validate`、`to_json` 及 serde 解码。
外部边界使用 Envelope 校验，不直接将裸 payload 视为完整有效消息。

在根目录运行 `./scripts/cargo.sh test --locked`。M1 接入工作见 `../docs/VERITAS_PATCHES.md`。
