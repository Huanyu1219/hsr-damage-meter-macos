# ADR 0002 — 原生显示与原浮窗隔离实验

状态：已采纳（2026-09-13）

为隔离游戏内浮窗的性能影响，先实现独立可运行的 Mac 接收面板，再使用单变量 DLL 构建跳过上游浮窗初始化。

## 实现

- SwiftUI 原生窗口、三张指标卡、伤害排行、连接状态、重连、带确认的重置与菜单栏。
- URLSessionWebSocketTask 连接已有 Engine.IO v4 / Socket.IO 默认 namespace，固定 loopback 1305。
- 仅实现当前 0.2.52 所需文本事件、握手、心跳、断连重试；不是通用 Socket.IO 客户端。
- LiveCombatStore actor 顺序处理事件；UI 最高 10 Hz 读取快照，无逐事件动画。
- 保留源 JSON 小数，用 Decimal 聚合；浮点源精度不可恢复。DPS 为本机接收时间估计，不冒充游戏时间。
- 对晚连接、断线、未知归属与结算差异显示不完整。上游没有序列号，无法保证检测所有丢包/重排。
- `VeritasNetworking`、`LiveDomain`、`NativeApp` 和 `LiveTests` 与 v1 协议模型隔离。
- 原生 App 通过 Swift Package 构建并封装 .app；不创建空 xcodeproj。

## DLL 对照

0002 补丁只跳过 entry.rs 中 overlay::initialize，不安装其 D3D11 绘制处理。
保留游戏集成、数据处理、Socket.IO、日志级别；不要同时应用 0001 日志补丁。
仍保留 UI 源文件/依赖便于对照上游，不等于删除所有 UI 相关代码和日志内存开销。
若构建工具链与官方不同，也须记录为实验限制，不能把任何差异都归因于 UI。

## 静态数据

经用户指定，直接下载 Nanoka 网页引用的公开 character.json 4.5.54。
原始数据、来源 URL、版本、SHA-256 与许可状态放入 LiveDomain/Resources。
仅用于 ID→中文显示名。网站版本号不能证明采集兼容性，也不标为已经独立确认的“正式服完整数据包”。
当前本地包不包含全部技能资料/图像；未知 ID 保留源端名字或角色编号。
第三方素材的再分发许可尚未确认，在项目公开发布前独立核验。
