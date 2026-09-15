# 最小原生 Mac 接收端

构建：`./scripts/build-macos-app.sh`。
产物：项目根目录 `dist/HSR Damage Meter.app`（本地 ad-hoc 签名，无开发者公证）。
正常启动后自动连接 `ws://127.0.0.1:1305/socket.io/?EIO=4&transport=websocket`。
启动游戏并开始新战斗可获得完整观察区间；中途连接只能累计后续收到的事件。
关闭主窗保留菜单栏与连接，菜单栏可重新打开主窗或退出。

数字仅在显示时缩写，累计保留小数。鼠标停留角色伤害可看精确值。
4.5 兼容性提示始终保留；原 DLL 漏记的数据无法在 Mac 端推测还原。

## 离线预览

```sh
open -n 'dist/HSR Damage Meter.app' --args --demo
```

演示模式明确标记，不连接 Collector。

## 测试

普通单元测试：`swift test --package-path macos/HSRDamageMeter -j 2`。
网络集成测试需要先退出游戏，确保 1305 无真实 Collector 占用：

```sh
.tools/validation-venv/bin/python scripts/mock-veritas.py
# 另一个终端
HSR_MOCK_TEST=1 swift test --package-path macos/HSRDamageMeter -j 2
```

mock 固定 loopback，验证真实 WebSocket 握手、namespace、ping/pong、小数及结算。
完成后 Ctrl+C 关闭 mock，以免占用游戏 Collector 端口。mock 数据不是真实战斗数据。
