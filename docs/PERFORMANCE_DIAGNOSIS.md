# Veritas 0.2.52 卡顿初诊 — 2026-09-13

## 已验证

- 验证环境为外置磁盘游戏目录；YAAGL HSR，Wine 11.0，GPTK 4 beta 2。
- 用户反馈：不加载 DLL 不卡；加载后进入战斗/技能卡顿；Ctrl+H 隐藏 UI 后仍然卡顿。
- DLL 校验值与官方 0.2.52 发布物一致，来源及 revision 见 adr/0001-reuse-veritas-socketio.md。
- 本地 config.ini 明确记录 `game_version=4.5.0`；官方 0.2.52 发布说明为 `Game Version: 4.3.54+`，不能将加号视为已验证 4.5 兼容。
- 源码 AliveState 包含 `WillBeDestroyed`，而运行日志报告实际解析名 `WillBeDestroy` 无匹配，已有具体的名称不匹配证据。
- on_combo 的技能空名错误来自读取嵌套字段后检测到空指针，不只是角色名称字典缺项；可能是版本布局/路径变化或该事件分支本来无技能名，尚未归因。
- 14:57 启动时 debug 日志约 1.8 KB；后续采样已达 118,178 行 / 11,924,071 bytes，随后文件增长到 22,735,011 bytes。
- 最近日志大量重复 il2cpp 字段/方法解析和调用，例如 GetFields、GetTypeFromHandle、_OwnerRef。
  后续 3 秒采样无增长，说明不能把累积大小等同持续写入速率；尚无帧时间关联测量。
- 对应 release 源码 `src/logging.rs` 使用 PlainSyncDecorator + Mutex 写日志，全局启用 LevelFilter::Trace。
- 还有 WillBeDestroy 枚举未识别、on_combo 技能名称为空的错误；这些是兼容性/数据完整性线索，不能直接认定为卡顿根因。

## 当前结论

优先核验 4.5 兼容性和新角色事件正确性；性能方面怀疑高频 Debug 日志同步格式化/写入，以及上游重复反射解析的成本。
隐藏 UI 未改善，说明单纯减少可见图表不足；隐藏也不等于彻底卸载渲染处理。
这些证据不能证明日志是唯一根因，更不能承诺原生 App 一定消除卡顿。

## 已做的低影响验证

Mac 只读接入已运行的 loopback 服务，短暂采集 100 个事件后主动断开：
Connected 1、OnStatChange 89、OnDamage 6、OnTurnBegin 2、OnUseSkill 1、OnTurnEnd 1。
真实 damage 样例为 `367648.1990259297`，Player uid 1413，类型 Servant。
这验证了现有伤害导出可用；中途观察不是完整战斗验收。
没有修改游戏目录、DLL、游戏配置或进程内存；测试期暂停重型编译。

复现现有接口探测（游戏正在运行且加载 Veritas）：

```sh
python3 scripts/probe-veritas.py --seconds 10
```

探测固定本机地址，关闭代理，仅做 Socket.IO 握手、心跳和读取，结束主动关闭自身连接。
无事件时可提前结束，不会控制战斗。性能对比时不要同时运行探测，以保持条件一致。

## 候选修复与验证次序

`collector/patches/0001-default-info-logging.patch` 只将默认日志级别 Trace 改成 Info。
保留 Info、Warn、Error，不动战斗采集或 Socket.IO；宏级过滤可跳过 Debug/Trace 消息的求值与写入。
补丁仅通过固定 release 源码的 `git apply --check`；尚未编译 DLL、未部署、未验证帧时间改善。

1. 先核对上游对 4.5 的支持及已知错误；结束游戏后才使用固定源码/依赖构建日志候选 DLL，并保留官方 DLL 的独立备份。该候选只用于性能 A/B，不声称补齐 4.5 支持。
2. 重启，以同场景、同画质、同隐藏状态对比原版与候选版；重复已热身的相同技能，记录帧时间和 debug 日志增长。
3. 检查启动、伤害事件、战斗结束仍正常，且统计与原版一致。
4. 若收益不足，再分析重复解析、共享锁和广播任务，不把多个改动混在第一次 A/B 中。

不要在游戏运行时替换 DLL、删除/截断日志或尝试动态补丁。
现有源码没有可直接使用的日志级别配置；单纯设置 RUST_LOG 不会覆盖硬编码 Trace。
当前没有“可立即安装且已经修复”的 DLL，候选补丁不应被描述为验证成功的修复。

## 原生 UI 隔离实验结果

无 UI 版 DLL 已构建、备份安装并在真实游戏启动日志中确认禁用浮窗初始化。
用户反馈 Mac 面板有伤害、游戏仍卡顿。本次日志仍达约12万行/12.1MB，
下一变量为 Debug/Trace 日志关闭；等待退出游戏后构建和切换，暂不改变采集算法。
