# 实时面板参考与数据取舍

以下项目仅用于研究信息结构和交互；本项目不复制其 UI 源码或标志，所有 SwiftUI 组件均独立实现。

| 来源 | 核对位置 | 采用的思路 |
| --- | --- | --- |
| [Veritas 0.2.52](https://github.com/hessiser/veritas/tree/28691573a1ad74bd823d30db2d52d61e9f0b754a) | src/ui/widgets.rs：show_character_damage_widget、draw_damage_category_grid、show_battle_metrics_widget | 角色排行和明细表并存；分类伤害区分选择占比与全队占比 |
| [HunterPie](https://github.com/HunterPie/HunterPie/blob/ef654889658684848cb465176b676b9b553ea102/HunterPie.UI/Overlay/Widgets/Damage/View/PlayerViewV2.xaml) | PlayerViewV2 的 Damage Data、Contribution、DPS | 紧凑头像/排行条、伤害与占比的清晰层级 |
| [Details!](https://github.com/Tercioo/Details-Damage-Meter/blob/17e716eb2709a68fd0b89096f873941362732b5b/frames/window_breakdown_midnight/window_headers.lua) | column headers、canSort、header widths | 明细表按数值排序、清楚的列标题；用 SwiftUI Table 实现 |

## 已采用的设计

伤害占比图与明细表同时展示，点击角色可联动伤害类型详情。
表格包括角色、伤害、全队占比和 DPS，并支持按数值排序。
伤害类型来自 `OnDamage.type`，通过经过核验的映射显示中文；未知值保留原始标签。
缺省/null 分类归入“未提供分类”，新标签自动保留。类型累计与角色/全队总伤害一致。
分母分别为当前选择角色伤害和全队伤害；选择全队时两列一致。

## 需先核验的数据

| 指标 | 数据来源/风险 | 后续要求 |
| --- | --- | --- |
| DPAV | Veritas 使用 action_value；不是墙钟 DPS | 对照回合/行动值事件和重置边界后再实现 |
| 有效/溢出伤害 | 上游有 overkill_damage，UI 曾采用 damage-overkill；当前采集还涉及HP差 | 先核对源字段的口径，避免重复扣减 |
| 技能明细 | OnUseSkill 与伤害并非自带可靠关联ID | 先验证多段、召唤物和4.5角色归属，不能按相邻事件臆测 |
| 分类中文名 | Servant、True 等原始标签来自上游映射 | 核对4.5实际语义后单独维护显示映射 |
| 历史/趋势 | 需要会话存储与一致性验证 | 修改时保持历史结算与实时聚合口径一致 |

DPS仍以本机观察时长估算（悬停说明），不作为游戏回合效率。
界面不显示端口、开发说明或重复状态文案；演示数据只保留必要标识，数据不完整或结算异常仍显示提示。

## 角色素材

名称来自 Nanoka 4.5.54；头像来自 [Mar-7th/StarRailRes](https://github.com/Mar-7th/StarRailRes/tree/d226befe3db13f2ec15f4161d5f34b1b607643fe) 的 icon/avatar。
97张PNG在本地打包并缓存；1503没有对应源文件，未知或缺失头像使用姓名首字占位。
每张素材URL、版本、hash见 LiveDomain/Resources/portraits-source.json。未将项目开源许可证套用到游戏素材；发布前仍需核验再分发权利。
