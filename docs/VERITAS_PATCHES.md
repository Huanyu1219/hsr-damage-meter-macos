# Veritas 变更记录

上游固定为 hessiser/veritas 0.2.52（commit `28691573a1ad74bd823d30db2d52d61e9f0b754a`，MIT）。原始源码保存在 `collector/upstream-veritas/`，本项目的差异以可复现补丁保存在 `collector/patches/`。

| 候选补丁 | 上游文件 | 原因与修改 | 依赖与验证 |
| --- | --- | --- | --- |
| 0001-default-info-logging.patch | `src/logging.rs` | 默认日志级别由 Trace 改为 Info，避免战斗期间同步写入大量调试日志 | Release 构建、Wine 加载和真实战斗验证通过；不改变事件采集精度 |
| 0002-disable-overlay-initialization.patch | `src/entry.rs` | 跳过 `overlay::initialize`，由原生 App 显示数据；采集、日志和 Socket.IO 保持不变 | Clang/MS 扩展与 MinGW 交叉构建、Wine 加载和真实战斗验证通过 |

游戏更新后必须重新核验 Wine 加载、事件兼容性和统计完整性。每个补丁应记录上游文件、修改原因、最小差异、依赖和上游 revision，避免无关重命名、格式化或架构重写。
