# Contributing

感谢参与 HSR Damage Meter。提交变更即表示你有权按项目的 AGPL-3.0 许可证贡献该内容。

## 开发环境

- macOS 14 或更高版本、Swift 6 / Xcode Command Line Tools
- Rust 1.98.1
- Python 3.10 或更高版本

```sh
python3 -m venv .tools/validation-venv
.tools/validation-venv/bin/python -m pip install -r scripts/requirements-validation.lock
./scripts/check.sh
```

构建 App：

```sh
./scripts/build-macos-app.sh
```

## 分支与提交

- `feat/<topic>`：功能
- `fix/<topic>`：修复
- `docs/<topic>`：文档

提交信息遵循 Conventional Commits，例如 `fix(history): retry failed settlement`。一个 PR 只处理一个独立问题，保持公共接口兼容，附上验证命令和结果。

## 代码要求

- Swift 使用 Swift 6 严格并发；提交前运行 `xcrun swift-format lint --strict --recursive macos/HSRDamageMeter`。
- Rust 运行 `cargo fmt --check` 和 `cargo test --locked`。
- 不提交密钥、Token、真实战斗记录、游戏安装路径、DLL 构建产物或个人数据。
- 第三方素材必须记录来源、固定版本、校验和与许可证。许可不明确的素材不得新增到仓库。
- 修改协议、存储格式或重要架构决策时，同步更新 Schema、测试和 ADR。

## PR 审核

PR 需要通过 CI。涉及 Collector、协议、SQLite、下载边界或权限的变更应包含失败路径测试。UI 变更应提供可复现的离屏渲染或人工验收说明，不要提交用户屏幕截图中的私人信息。
