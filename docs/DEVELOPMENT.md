# 开发与验收

所有命令均从项目根目录运行。主分支为 `main`；功能、修复和文档分支分别使用 `feat/<topic>`、`fix/<topic>` 和 `docs/<topic>`。提交信息遵循 Conventional Commits。

## 工具与依赖

- macOS 14+
- Swift 6 / Xcode Command Line Tools
- Rust 1.98.1
- Python 3.10+

Rust 版本由 `rust-toolchain.toml` 固定，`scripts/cargo.sh` 会优先使用仓库本地工具链，也兼容系统 Cargo。Swift 包没有外部依赖。

```sh
python3 -m venv .tools/validation-venv
.tools/validation-venv/bin/python -m pip install -r scripts/requirements-validation.lock
./scripts/check.sh
```

构建可运行 App：

```sh
./scripts/build-macos-app.sh
open 'dist/HSR Damage Meter.app'
```

## 检查范围

`scripts/check.sh` 运行 Rust 与 Swift 测试、JSON Schema 校验、跨语言序列化检查及格式检查。协议变更必须覆盖合法数据、无效版本、必填字段、未知值和整数边界。涉及连接、SQLite、下载或权限的改动还应覆盖失败及恢复路径。

真实游戏联调需验证完整战斗、战斗中连接、断线重连和结算行为。由于上游 Socket.IO 没有重放和全局序列保证，客户端必须把中途连接或丢失连接的场次标为不完整。

`.env.example` 记录可选开发配置；`.tools/`、构建产物和真实环境文件均由 `.gitignore` 排除。
