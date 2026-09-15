# 实时面板参考与数据取舍

本轮仅参考信息结构和交互，不复制其他项目的 UI 源码或标志。原生 SwiftUI 组件独立实现。

| 来源 | 核对位置 | 采用的思路 |
| --- | --- | --- |
| [Veritas 0.2.52](https://github.com/hessiser/veritas/tree/28691573a1ad74bd823d30db2d52d61e9f0b754a) | src/ui/widgets.rs：show_character_damage_widget、draw_damage_category_grid、show_battle_metrics_widget | 角色排行和明细表并存；分类伤害区分选择占比与全队占比 |
| [HunterPie](https://github.com/HunterPie/HunterPie/blob/ef654889658684848cb465176b676b9b553ea102/HunterPie.UI/Overlay/Widgets/Damage/View/PlayerViewV2.xaml) | PlayerViewV2 的 Damage Data、Contribution、DPS | 紧凑头像/排行条、伤害与占比的清晰层级 |
| [Details!](https://github.com/Tercioo/Details-Damage-Meter/blob/17e716eb2709a68fd0b89096f873941362732b5b/frames/window_breakdown_midnight/window_headers.lua) | column headers、canSort、header widths | 明细表按数值排序、清楚的列标题；用 SwiftUI Table 实现 |

## 本轮已采用

默认排行，用户可切换原生表格，选择持久化。点击角色选择联动详情和类型表。
表格包括角色、伤害、全队占比、DPS、最高单次、次数；角色/伤害/最高单次/次数可排序。
伤害类型来自 OnDamage.type 原始字符串，不做猜测性中文映射。
缺省/null 分类归入“未提供分类”，新标签自动保留。类型累计与角色/全队总伤害一致。
分母分别为当前选择角色伤害和全队伤害；选择全队时两列一致。

## 尚待确认，不混入本轮计算

| 指标 | 数据来源/风险 | 后续要求 |
| --- | --- | --- |
| DPAV | Veritas 使用 action_value；不是墙钟 DPS | 对照回合/行动值事件和重置边界后再实现 |
| 有效/溢出伤害 | 上游有 overkill_damage，UI 曾采用 damage-overkill；当前采集还涉及HP差 | 先核对源字段的口径，避免重复扣减 |
| 技能明细 | OnUseSkill 与伤害并非自带可靠关联ID | 先验证多段、召唤物和4.5角色归属，不能按相邻事件臆测 |
| 分类中文名 | Servant、True 等原始标签来自上游映射 | 核对4.5实际语义后单独维护显示映射 |
| 历史/趋势 | 需要会话存储与一致性验证 | 按M7/M8单独推进 |

DPS仍以本机观察时长估算（悬停说明），不作为游戏回合效率。
用户要求的简洁呈现已落实：移除端口、版本、开发说明、“本地预览”和“实时战斗”重复文案；
演示构建只保留“演示”标识，数据不完整/结算异常保留必要提示。

## 角色素材

名称来自 Nanoka 4.5.54；头像来自 [Mar-7th/StarRailRes](https://github.com/Mar-7th/StarRailRes/tree/d226befe3db13f2ec15f4161d5f34b1b607643fe) 的 icon/avatar。
97张PNG在本地打包并缓存；1503没有对应源文件，未知或缺失头像使用姓名首字占位。
每张素材URL、版本、hash见 LiveDomain/Resources/portraits-source.json。未将项目开源许可证套用到游戏素材；发布前仍需核验再分发权利。
