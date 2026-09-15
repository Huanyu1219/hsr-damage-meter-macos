# UI 规范入口

CODEX_SPEC.md 第 13–42、48–53、57 节为权威 UI 契约，本文件仅作索引。

- 原生 SwiftUI + 必要 AppKit；四个导航目的地：Live、History、Analysis、Settings。
- 主窗最小 900×620，默认 1120×760；NavigationSplitView 侧栏 180–220。
- Live 三张主指标卡、稳定 ID 的伤害排行；条宽按最高角色伤害，百分比按队伍总伤害。
- SF Pro、统一间距/圆角、等宽数字、0.15–0.25 秒克制动效；遵守辅助功能设置。
- NSPanel 浮窗有 Minimal/Compact/Detailed，默认 Compact；菜单栏必须能恢复鼠标穿透。
- 关闭主窗不退出；空、离线、就绪状态清晰；真实数据不支持的技能/遭遇信息不得虚构。
- M4 开始 DesignSystem 与 Live，每个主要视图必须有预览 fixture。

M0 不实现或润色 UI。完整线框、令牌与交互细节直接查阅权威文档，避免维护重复副本。
