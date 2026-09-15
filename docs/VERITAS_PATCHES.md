# Veritas 变更记录

M0：未导入或修改任何上游代码、hook 或游戏集成。

2026-09-13：已只读检出 hessiser/veritas tag 0.2.52（commit 28691573a1ad74bd823d30db2d52d61e9f0b754a）到 .tools/veritas-inspection，许可证为 MIT。
现有 Socket.IO 已可导出数据，用户批准直接复用。游戏文件及 DLL 未修改。

后续 UI 隔离迭代：已原样导入固定上游至 collector/upstream-veritas；在独立 staging 应用 0002 并构建。
no-ui 版本已在游戏停止时安装，官方 DLL 已按 SHA-256 备份。同工具链 control 版本同时提供，详见 UI_ISOLATION_ACCEPTANCE.md。

| 候选补丁 | 上游文件 | 原因与修改 | 依赖与验证 |
| --- | --- | --- | --- |
| 0001-default-info-logging.patch | src/logging.rs | Trace 改为 Info，抑制高频调试日志以进行性能 A/B | 已在第二轮叠加于no-ui，release构建及隔离Wine加载通过，已备份安装no-ui-info；真实战斗效果待验收，不是4.5兼容性修复 |
| 0002-disable-overlay-initialization.patch | src/entry.rs | 跳过 overlay::initialize，以原生 App 替代游戏内绘制；其他采集/日志/导出不改 | 无新增源码依赖；Clang MS 扩展 + MinGW 交叉构建通过，隔离 Wine LoadLibrary通过，已备份安装；真实战斗待验收 |

尚待核验：固定依赖的 Windows 构建，以及当前游戏 4.5 / Wine 组合的兼容性和统计完整性。
每次补丁记录上游文件、修改原因、最小补丁摘要、依赖及上游 revision。
优先既有事件订阅和窄适配器，保留原 UI 与现有行为；禁止无关重命名、格式化及架构重写。
不加入反作弊绕过、隐藏或规避功能。
