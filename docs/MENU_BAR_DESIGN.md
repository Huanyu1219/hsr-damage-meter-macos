# 菜单栏状态图标

参考 Apple 官方资料：

- https://developer.apple.com/design/human-interface-guidelines/the-menu-bar ：推荐符号或黑色/透明图形，适配明暗菜单栏及选中状态；菜单栏高度为 24pt，点击优先显示菜单。
- https://developer.apple.com/documentation/appkit/nsimage/istemplate ：模板图像使用黑色及透明，通过 alpha 控制不透明度。
- https://developer.apple.com/documentation/swiftui/menubarextra ：沿用系统菜单栏入口，不另造顶部窗口。

本项目设计选择：18pt 固定图标（非 Apple 强制尺寸），1×/2×资源；用户新图中的白色月牙及火焰转为透明底单色轮廓，去掉灰色细节。空闲 alpha 0.55，统计中 alpha 1，右下角 4pt 绿点及对比边缘。绿点是本应用状态，不是系统隐私指示器。不闪烁、不随每次伤害改变宽度。

为保留绿色，最终状态图使用 original rendering 而非全图 template；按 SwiftUI 菜单栏 colorScheme 选择白/黑前景，缓存四个状态。自动化验证了两种外观的尺寸、绿色像素及状态条件；真实菜单栏壁纸/选中高亮效果仍可按实机反馈微调。

点亮条件：非演示、连接成功、场次活动且未结束、本场伤害次数大于零、本次连接收到玩家伤害。断线、初始化新场次或结算清除新数据标记；连接恢复后等新伤害再点亮。无需新增定时器或游戏端日志。语音辅助标签和悬停文本补充状态，不单靠颜色。

源图为 `macos/Assets/MenuBarCombatSource.png`；`scripts/make-combat-menu-icon.swift` 生成透明主图及 18/36px 资源。Dock/Finder 使用 `macos/Assets/AppIcon.png`。

验证：31项Swift测试通过，2项外部联调跳过；构建、签名及格式检查通过。新增菜单栏活动条件和实际图像尺寸/像素检查。
