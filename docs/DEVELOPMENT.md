# 开发与验收

先读取 `.project-state.json`，以项目根目录执行命令。规范来源为根目录 CODEX_SPEC.md。
采用 main 主分支；功能分支 `feat/<topic>`、修复 `fix/<topic>`、文档 `docs/<topic>`。
提交遵循 Conventional Commits；PR 限定一个子任务并附验收结果。
Rust 使用 rustfmt，Swift 使用 Swift 6 严格并发与原生命名；GitHub Actions 对 PR 和 main 推送执行格式、测试、Schema、构建及高危依赖检查。

## 工具与依赖

Rust 固定 1.98.1，依赖固定在 collector/Cargo.lock。安装了系统 rustup 的环境执行：

```sh
rustup toolchain install 1.98.1 --profile minimal
```

本机初次运行已将 Rust 隔离于 `.tools/cargo` 与 `.tools/rustup`；scripts/cargo.sh 自动选择它们，
不会修改系统 PATH。其他环境也可直接使用已有 Cargo。Swift 无外部依赖，故不生成空 Package.resolved。

```sh
python3 -m venv .tools/validation-venv
.tools/validation-venv/bin/python -m pip install -r scripts/requirements-validation.lock
./scripts/check.sh
```

`HSR_VALIDATION_PYTHON` 可指定已安装锁定验证依赖的 Python。`.env.example` 为 M1 配置契约占位，M0 不加载它。
`.tools/`、构建输出与真实环境文件由 .gitignore 排除。

## 检查内容

1. Rust / Swift 编译和单元测试：所有事件、版本拒绝、必填字段、未知值、整数边界。
2. 七个 Draft 2020-12 Schema 自检、合法/非法 fixture 验证。
3. Rust→Swift 与 Swift→Rust 双向序列化并对比完整已知数据及输出 Schema。

以上是本地协议验收，不代表 Windows Collector、Wine 网络或 macOS GUI 已验收。
M1 先确认 Veritas 上游版本和许可，再观察已解析事件、实现有界异步桥与 localhost WebSocket，
验证原行为保持、慢客户端隔离、序列/会话和断连行为，并逐项记录上游补丁。
