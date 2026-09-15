# ADR 0001 — 复用 Veritas 现有 Socket.IO

状态：已采纳（2026-09-13）

## 证据

- Veritas Method 2 可将 DLL 作为 `xluau.dll` 加载，并正常提供战斗事件。
- 上游：https://github.com/hessiser/veritas，MIT；版本 0.2.52，commit `28691573a1ad74bd823d30db2d52d61e9f0b754a`。
- 官方 release asset 与游戏目录 DLL 的 SHA-256 均为 `d0bd2287b7b30f962a7a208c090bbe0ba2cff06e16dbc16ec1071821ea7667b2`。
- Mac 实测 `127.0.0.1:1305/socket.io/?EIO=4&transport=polling` 成功，并收到 Connected 0.2.52 与真实 OnDamage。
- 上游源码 `src/server.rs` 已有 loopback Socket.IO 服务器；`src/battle.rs` 广播已解析 Packet。

## 决定及目录影响

先复用 DLL 的现有 Socket.IO，Mac 端增加独立兼容解码与聚合层，不依赖 IL2CPP。
Networking 放传输/解码，Domain 放聚合，App 放最小显示。无需另加 Rust 发布器，也无需为导出重新编译 DLL。
现有 Rust/Swift v1 模型保留为独立协议边界；现有上游服务不视为符合 v1。
`scripts/probe-veritas.py` 为现有接口的轻量诊断入口，不是最终 App。

## 必须处理的兼容差异

- Socket.IO 是 Engine.IO 上的额外协议，不能把 URLSession WebSocket 收到的帧直接当 v1 JSON。
- 现有端口 1305；原 v1 端口 13051 不适用于现有 DLL。
- Packet 名为 Connected、OnBattleBegin、OnSetBattleLineup、OnDamage、OnBattleEnd 等。
- damage 为 f64，真实样例含小数；不得直接转换为 Int64。接收端保留线上的小数数值，注明源端浮点精度边界。
- 没有 v1 的序列号、事件时间或 session UUID；不能补造为 Collector 保证。
- 连接发生在战斗中途或中途断线时，必须标记统计不完整；无重放保证。
- 队伍 Avatar.id 与 Player attacker.uid 的映射须按此版本已解析语义验证，不能根据显示名关联。
- 现有广播每次 spawn 异步任务，没有本项目承诺的有界队列；Mac 端不能据此保证 Collector 永不受背压影响。

## 性能边界

性能对照显示，不加载 DLL 时无卡顿，隐藏上游浮窗后仍有卡顿；最终定位到高频 Trace 日志，默认降为 Info 后恢复流畅。复用网络接口本身不消除采集或日志开销。
游戏 4.5.0 与上游发布时声明的数据版本存在差异，曾观察到枚举名称不匹配及技能空名错误。
接收端必须标记此版本组合未验证；新角色正确性优先核验，不能在 App 中推测和补造漏失事件。
日志和浮窗变更以独立补丁维护，见 `docs/VERITAS_PATCHES.md`。
