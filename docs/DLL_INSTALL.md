# Collector DLL 安装指南

Mac App 本身不读取游戏进程。游戏目录中的 Veritas Collector 负责解析战斗事件，并通过 `127.0.0.1:1305` 发送给 App。

## 推荐版本

从本项目 [最新 Release](https://github.com/Huanyu1219/hsr-damage-meter-macos/releases/latest) 下载 `xluau.dll` 和 `SHA256SUMS.txt`。同一页面还提供可直接安装的 `HSR-Damage-Meter-macOS-arm64.zip`。

当前发布文件基于 Veritas 0.2.52，应用两项可审查补丁：

- 不初始化游戏内 UI，数据改由 Mac App 显示。
- 默认日志等级由 Trace 降为 Info，避免战斗期间高频调试写盘。

SHA-256：

```text
45bb9f35852a6dd8292d317b7e154233105e5be5131abec537a2357c63269036  xluau.dll
```

该文件已在 YAAGL、Wine 和 GPTK 环境中完成实战验证。游戏更新可能改变兼容性；收到事件不等于新版本所有伤害类型都已正确解析。

## 放置位置

必须先完全退出游戏和 YAAGL/Wine 容器。找到包含游戏主程序的目录：

```text
Honkai Star Rail/
├── StarRail.exe
└── xluau.dll
```

如果已有 `xluau.dll`，先复制一份到游戏目录之外作为备份。下载文件若使用其他名称，重命名为小写的 `xluau.dll`，与 `StarRail.exe` 放在同一级；不要放进 Mac App、Wine 系统目录或其他子目录。

在终端核对文件：

```sh
shasum -a 256 '/path/to/Honkai Star Rail/xluau.dll'
```

输出必须与上方校验值一致。然后先启动游戏，再打开 Mac App。正常情况下，App 会从“正在连接”变为“Collector 已连接”。

## 官方原版替代方案

也可以从 [Veritas 0.2.52 官方 Release](https://github.com/hessiser/veritas/releases/tag/0.2.52) 下载 `veritas.dll`，重命名为 `xluau.dll` 后放在同一位置。官方版本带有游戏内 UI 和原始日志设置，本项目此前的性能对照中出现过明显卡顿，因此不作为推荐版本。

## 回滚或移除

完全退出游戏后，删除当前 `xluau.dll` 并恢复安装前的备份。没有备份时，可重新下载上方官方原版；若希望完全停用 Collector，则不要在游戏根目录保留 `xluau.dll`。

仓库中的 `scripts/install-collector.py` 面向开发者本地构建产物，需要 `dist/collector-manifest.json`，不适用于只下载 Release 的普通用户。
