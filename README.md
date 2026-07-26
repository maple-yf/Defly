# Defly

Defly 是一款原生 macOS 默认应用管理工具，用来查看并安全修改文件类型、UTType 与 URL Scheme 的默认处理应用。

项目参考 [SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps) 的能力范围，但采用独立 App、现代 Apple 公共 API 和明确的二次确认流程，不读写私有 LaunchServices 数据库。

## 当前状态

Defly V1 已完成可构建实现：

- 概览页展示默认浏览器、默认邮件和自定义固定项目
- 浏览器智能组合明确覆盖 `http`、`https` 与 `public.html`
- 文件类型页支持按 UTType、扩展名、MIME 类型和本地化名称搜索
- URL Scheme 页支持协议和候选应用检查
- 应用页可从已安装 App 反查其声明的文件类型与 URL Scheme
- 优先列出 macOS 返回的兼容应用，也可手动选择其他 `.app`
- 所有写入都先展示原生确认 Sheet，不会因列表选择而直接修改系统
- 变更串行执行，完成后逐项回读并区分已验证、失败与未生效
- 部分成功时保留成功项，只重试失败或未生效项
- 中文与 English 即时切换并持久保存；首次启动固定使用中文
- 支持浅色、深色、高对比度与“降低透明度”

V1 坚持手动管理，不包含后台进程、菜单栏常驻、自动恢复、历史回滚、配置档案、导入导出或 CLI。

## 系统要求

- macOS 14 或更高版本
- Xcode 16 或更高版本
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- `jq`（用于验证 String Catalog）

安装开发依赖：

```bash
brew install xcodegen jq
```

## 构建与运行

```bash
git clone https://github.com/maple-yf/Defly.git
cd Defly
xcodegen generate
open Defly.xcodeproj
```

在 Xcode 中选择 `Defly` Scheme 后运行。实际修改默认应用时，macOS 可能显示额外的系统同意提示；拒绝后对应关联保持不变。

也可以在命令行构建无签名调试产物：

```bash
xcodebuild build \
  -project Defly.xcodeproj \
  -scheme Defly \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## 验证

```bash
./scripts/verify.sh
```

验证脚本会：

1. 重新生成 Xcode 工程并校验 String Catalog 与补丁格式。
2. 构建并直接运行 `DeflyCoreTests`。
3. 编译 UI 测试 Bundle。
4. 构建 Defly macOS App。

完整 UI 自动化需要当前 Mac 为 XCTest 授予“自动化”权限，可在 Xcode 中运行 `DeflyUITests`。测试覆盖中文首次启动、文件类型搜索、二次确认与部分失败，以及英文切换后的重启持久化。

## 安全边界

- 只使用 `NSWorkspace` 与 `UniformTypeIdentifiers` 公共 API
- 不直接操作 LaunchServices 私有数据库
- 不请求管理员权限，不安装 Helper
- 不联网，不包含遥测
- App Sandbox 关闭以发现标准 Applications 目录，Hardened Runtime 开启
- 手动选择非系统候选应用时会明确显示兼容性警告

## 工程结构

```text
Sources/
├── DeflyApp/       SwiftUI 界面、依赖组装与本地化
└── DeflyCore/      领域模型、应用发现、变更计划与执行
Tests/
├── DeflyCoreTests/
└── DeflyUITests/
```

`DeflyCore` 不依赖 SwiftUI，可供未来 CLI 或其他客户端复用。

详细设计与实施记录：

- [Defly macOS App 设计规格](docs/superpowers/specs/2026-07-26-defly-macos-app-design.md)
- [Defly V1 实施计划](docs/superpowers/plans/2026-07-26-defly-v1-implementation.md)

## English

Defly is a native macOS utility for inspecting and safely changing default handlers for file types, UTTypes, and URL schemes. V1 includes an overview, advanced explorers, explicit atomic change previews, read-back verification, partial-failure retry, and a persistent Chinese/English interface.

## 开源许可

Defly 以开源项目为目标。首次公开发布前仍需由项目所有者选择并加入 OSI 批准的许可证；在许可证文件加入仓库前，默认版权规则适用。
