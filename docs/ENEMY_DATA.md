# 敌方信息与资料更新

- 顶部指标字号由 34pt 调整为 28pt。
- `OnInitializeEnemy.enemy` 提供模板 ID、实例 UID、名称与基础 HP。实例 UID 作为聚合主键，同名怪物不会合并。
- `OnStatChange` 中 Enemy 的 CurrentHP / MaxHP 更新血量；不使用我方伤害扣算 HP，保留恢复与阶段变化。
- `OnUpdateTeamFormation` 标记在场/离场；`OnTurnBegin.turn_owner` / `OnTurnEnd` 标记行动中；`OnEntityDefeated` 标记击败。初始化晚于血量更新时保留已接收的实时值。
- 断线或结算后显示最后记录，完整增益/减益、控制状态和技能图标没有对应 Socket.IO 列表，本版不推测。敌方运行时协议仍受 Collector 4.5 兼容性限制。初始化 HP 本身来自上游 DefaultMaxHP，后续使用实际 HP 更新。
- 内置 Nanoka 4.5.54 的 632 条怪物模板，以 child 别名适配变体 ID；名称优先中文静态资料，缺失回退到 Collector 名称。图片使用站点 monstermiddleicon 路径（怪物立绘缩略图），按需下载并缓存；缺图用占位符，不阻断统计。
- “更新最新数据”位于重新连接左侧，从 Nanoka 首页实际 character.json 地址识别其发布版本，不把版本号推断为游戏正式服版本。已是同版/更高版本只提示“已是最新版本”；新版本下载 character.json 与 monster.json，校验后原子写入 Application Support/HSRDamageMeter/GameData/catalog.json。失败保留旧档案。角色名称/属性即时生效，角色头像仍使用已有离线包；怪物图片按资料版本隔离缓存。
- 来源及静态文件哈希：LiveDomain/Resources/monster-data-source.json。游戏美术的开源再分发权利未核验。

验证：27 项 Swift 测试通过，1 项模拟网络测试因真实游戏端口用途跳过。包括 Nanoka 在线版本/图片检查、无需更新时不下载数据集、更新成功、损坏更新不覆盖旧档案、缓存恢复、敌人生命周期和离屏卡片渲染。发布构建与签名通过。不修改现有无 UI + Info DLL。

实战验证：Cmd+Q 退出旧 App 后打开 dist/HSR Damage Meter.app，从新战斗开始检查敌人初始化与实时血量；点击更新按钮应提示当前数据版本结果。后续如需完整 buff/debuff 明细，先补充协议能力评估。
