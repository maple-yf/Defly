# Defly macOS App 设计规格

- 状态：已获产品与 UI 设计批准
- 批准日期：2026-07-26
- 产品负责人：Maple
- V1 平台：macOS 14 及以上

## 1. 产品定义

Defly 是一款独立、原生的 macOS 默认应用管理工具。它帮助用户查看和修改以下系统关联：

- URL Scheme，例如 `http`、`https` 和 `mailto`
- UTType，例如 `public.html`、`com.adobe.pdf` 和 `public.png`
- UTType 对应的文件扩展名与 MIME 类型
- 某个已安装应用能够处理的关联集合

Defly 参考 SwiftDefaultApps 的能力范围，但不复刻旧的 Preference Pane、私有 LaunchServices 数据库访问或历史 UI。V1 使用 Apple 当前公开的 `NSWorkspace` 与 `UniformTypeIdentifiers` API，构建一个可签名、公证和独立分发的现代 macOS App。

## 2. 目标

V1 必须做到：

1. 让普通用户在概览页安全完成常见默认应用设置。
2. 让高级用户从文件类型、URL Scheme 和应用三个角度检查系统关联。
3. 在写入前明确展示旧值、新值和全部原子变更。
4. 逐项执行和验证变更，不把多个系统写入伪装成原子事务。
5. 使用原生 macOS 交互、系统蓝主题和适度毛玻璃。
6. 提供中文与英文界面，首次启动默认中文。
7. 只使用公开 API，不要求管理员权限，不在后台常驻。
8. 将领域逻辑与 GUI 分离，为未来 CLI 保留复用边界。

## 3. V1 非目标

以下能力不进入 V1：

- 菜单栏常驻模式
- 后台监控、自动恢复或“防篡改”
- 历史记录与一键回滚
- 配置档案、批量预设、导入或导出
- CLI
- 自动更新器
- 云同步、账户系统、遥测或联网服务
- “Do Nothing”虚拟处理应用
- 创建系统和已安装应用都未声明的任意 URL Scheme
- 为单个文件设置专属处理器
- 直接读取或修改 LaunchServices 私有数据库
- Mac App Store 分发

多个关联的修改无法由公开 API 保证事务性，因此 V1 不提供回滚承诺。部分成功时保留真实结果，并允许重试失败项。

## 4. 已确认的产品决策

### 4.1 双层模式

Defly 使用两个复杂度层级：

- 概览：面向常见任务，以智能组合和固定项目为核心。
- Advanced：面向完整管理，提供文件类型、URL Scheme 和应用视角。

### 4.2 手动管理

所有修改都由用户在主 App 内发起。退出 App 后没有守护进程、菜单栏程序或定时检查。

### 4.3 智能组合

智能组合将一个用户意图展开成多个可审查的原子关联。例如“默认浏览器”包含：

- URL Scheme：`http`
- URL Scheme：`https`
- UTType：`public.html`

`.html` 和 `.htm` 是 `public.html` 的扩展名标签，只作为解释信息展示，不被错误计为额外系统写入。

### 4.4 自定义固定项目

用户可以从 Advanced 页面把单个关联或内置智能组合固定到概览。固定项目只保存稳定标识符，不缓存默认应用结果；每次展示时读取当前系统状态。

### 4.5 候选应用

应用选择器优先展示系统报告为兼容的应用，并按系统返回顺序排列。末尾提供“选择其他应用…”：

- 文件选择器只允许选择 `.app`。
- 非系统候选应用必须显示兼容性警告。
- 仍由 `NSWorkspace` 执行最终设置；Defly 不绕过系统验证。

### 4.6 开源与分发

Defly 以公开、开源项目为目标。V1 使用开发者签名和 Apple 公证的 DMG 独立分发，稳定后可增加 Homebrew Cask。首次公开发布前，项目所有者必须选择并加入 OSI 批准的许可证。

## 5. 信息架构

主窗口侧边栏固定包含：

1. 概览
2. 文件类型
3. URL 协议
4. 应用
5. 设置

初始窗口建议尺寸为 `1040 × 720 pt`，最小尺寸为 `880 × 600 pt`。窗口记住上次尺寸和位置，但不保存敏感数据。

### 5.1 概览

概览采用“分组式控制中心”：

- 顶部显示系统状态最近刷新时间和手动刷新按钮。
- “常用组合”默认包含默认浏览器与默认邮件。
- “已固定”默认包含 PDF、Markdown 和常用图像。
- 用户可以添加、移除和排序固定项目。
- 每个项目显示真实应用图标、应用名称和关联数量。
- 点击项目进入应用选择；不会在单击卡片时直接写入系统。

内置组合定义：

| 组合 | 原子关联 |
|---|---|
| 默认浏览器 | `http`、`https`、`public.html` |
| 默认邮件 | `mailto` |
| 常用图像 | `public.png`、`public.jpeg`、`public.heic`、`com.compuserve.gif`、`public.tiff` |

PDF 默认固定项对应 `com.adobe.pdf`。Markdown 优先使用系统可解析的 Markdown UTType；若安装应用声明了多个 Markdown UTType，Defly 必须逐项展示，不把它们静默合并。

### 5.2 文件类型

文件类型页采用“双栏列表 + 持续检查器”：

- 顶部搜索支持 UTType 标识符、扩展名、MIME 类型和本地化名称。
- 左栏按文档、图像、影音、开发与归档等类别分组。
- 右栏显示 UTType、全部已知扩展名、MIME 类型、当前默认应用和兼容应用。
- 过滤器包括“全部”“常用”“已固定”和“无默认应用”。
- 选择列表项只更新检查器；用户必须点击明确的更改操作。

公开 API 不提供整个 LaunchServices 数据库的全量枚举。Defly 的可发现类型目录由以下来源合并：

1. App 内置的常见系统 UTType 种子目录。
2. 已安装应用 `Info.plist` 中的文档类型、导入类型和导出类型声明。
3. 用户通过 UTType 标识符、扩展名或 MIME 类型进行的按需解析。

因此“Advanced”表示完整控制所有已发现或可解析的公开关联，不宣称枚举 macOS 的私有内部记录。

### 5.3 URL 协议

URL 协议页复用相同的双栏结构：

- 内置常见 Scheme 种子。
- 合并已安装应用 `CFBundleURLTypes` 中声明的 Scheme。
- 搜索支持 Scheme 名称和应用名称。
- 右栏显示当前默认应用、全部系统候选应用和声明该 Scheme 的应用。

Defly 可以查询和修改已发现或用户精确搜索到、且存在有效处理器的 Scheme。V1 不创建未知 Scheme 记录。

### 5.4 应用

应用页从应用角度浏览：

- 左栏显示已发现应用，支持名称和 Bundle ID 搜索。
- 右栏分组显示该应用声明或可处理的 URL Scheme 与 UTType。
- 每项同时显示当前是否由该应用负责。
- 用户可以选择一个或多个关联生成变更计划，但提交前仍进入统一确认流程。

应用发现使用系统元数据查询覆盖 `/Applications`、`/System/Applications` 和用户 Applications 目录。关联候选的最终权威来源始终是 `NSWorkspace`，而不是 `Info.plist` 静态声明。

### 5.5 设置

V1 设置页只包含必要选项：

- 语言：中文、English
- 固定项目管理入口
- 关于 Defly、版本和开源链接

首次启动语言固定为中文，不跟随系统语言自动改变。用户切换语言后立即更新 Defly 自有文案并持久保存。应用名称、文件类型本地化名称等系统提供内容保持 macOS 返回的文本。

## 6. 变更流程

### 6.1 创建计划

用户选择新应用后，`ChangePlanner`：

1. 将单项或智能组合展开为原子关联。
2. 读取每项当前默认应用。
3. 删除当前值与目标值相同的无效变更。
4. 验证目标是现存 `.app`。
5. 查询目标是否位于系统候选列表。
6. 生成稳定排序的 `ChangePlan`。

`ChangePlan` 包含：

- 计划 ID，仅用于当前进程
- 目标应用 URL、Bundle ID、显示名称与图标引用
- 每个原子关联的类型和稳定标识符
- 每项当前应用
- 候选兼容性状态
- 面向用户的扩展名、MIME 类型等解释标签

### 6.2 二次确认

Defly 使用附着于当前窗口的原生 Sheet：

- 主页面变暗，但保持空间上下文。
- 顶部展示当前应用到新应用的方向。
- 完整列出每个原子系统写入。
- 扩展名等标签与原子写入明确区分。
- 非系统候选应用显示警告。
- 明确说明 macOS 可能追加系统同意提示。
- 按钮为“取消”和“确认更改”。

取消不会产生任何写入。

### 6.3 执行

`ChangeExecutor` 按稳定顺序逐项调用 `NSWorkspace` 的异步公开 API：

- UTType 使用设置默认内容类型处理器的接口。
- URL Scheme 使用设置默认 Scheme 处理器的接口。
- 一次只等待一个调用，避免并发触发多个系统同意提示。
- 某项失败不会阻止后续项执行。
- 执行过程中禁止关闭 Sheet 或再次提交。

公开 API 可能触发 macOS 用户同意 UI。用户拒绝时，该项按失败处理，不推测或隐藏原因。

### 6.4 验证与结果

所有调用结束后，Defly 重新读取每个关联的实际默认应用：

- 已验证：系统实际值等于目标应用。
- 失败：API 返回错误且实际值未改变。
- 未生效：API 未返回错误，但实际值不等于目标应用。

结果 Sheet 行为：

- 全部成功：显示简洁成功状态，然后返回来源页面并刷新。
- 部分失败：Sheet 保持打开，逐项显示结果。
- “重试失败项”只为失败和未生效项创建新计划。
- “完成”保留已成功的系统状态，不承诺回滚。
- 提供可复制的本地诊断摘要，但不包含用户文件内容。

## 7. 视觉与交互设计

### 7.1 视觉方向

- 风格：Native Utility
- 材质：平衡毛玻璃
- 主题色：macOS 语义化系统蓝
- 图标：界面操作全部使用 SF Symbols
- 应用图标：从真实 `.app` Bundle 或 `NSWorkspace` 获取
- 不在实现阶段临时绘制自定义界面图标

系统蓝只用于品牌标记、当前导航、选中状态、焦点和主要操作。普通卡片、列表和文字维持中性色，避免大面积蓝色染色。

浅色、深色和高对比度模式分别使用语义色，不把原型中的 `#3478D4` 当作固定生产色值。

### 7.2 毛玻璃

- 标题栏、侧边栏和主要容器使用分层系统材质。
- 文字和数据区域优先可读性，不使用过强透明度。
- SwiftUI `Material` 无法满足窗口级效果时，使用边界清晰的 AppKit `NSVisualEffectView` 桥接。
- 开启“降低透明度”时使用不透明系统背景。
- 开启“减少动态效果”时禁用非必要位移和缩放动画。

### 7.3 交互

- 列表支持完整键盘导航。
- 默认按钮、取消按钮和焦点顺序遵循 macOS 习惯。
- 搜索使用系统搜索字段行为。
- 危险或非兼容选择不能只靠颜色表达。
- 所有状态图标同时提供文字和 VoiceOver 描述。

## 8. 技术架构

### 8.1 工程结构

V1 使用两个清晰边界：

```text
DeflyApp
├── SwiftUI 视图与 AppKit 视图桥接
├── 页面 ViewModel
├── 本地化与应用设置
└── 依赖组装

DeflyCore
├── 领域模型
├── 关联目录与应用发现
├── WorkspaceClient 协议与系统实现
├── ChangePlanner
└── ChangeExecutor
```

`DeflyCore` 不依赖 SwiftUI。未来 CLI 可以复用目录、计划和执行逻辑，而不导入 App UI。

工程采用 Swift 和 Apple SDK，不在 V1 引入第三方运行时依赖。最低系统版本为 macOS 14，不为 macOS 12 或 13 编写兼容分支。

V1 采用非 App Sandbox 的独立分发构建，以读取标准 Applications 目录并管理系统级处理器关联；同时启用 Hardened Runtime、代码签名和公证。应用不借此扩大功能范围，也不申请无关权限。

### 8.2 核心领域模型

```text
AssociationID
├── contentType(identifier)
└── urlScheme(scheme)

HandlerApplication
├── applicationURL
├── bundleIdentifier
├── displayName
└── compatibility

DefaultAssignment
├── association
└── currentHandler

ChangePlan
└── [PlannedChange]

ChangeReport
└── [ChangeItemResult]
```

领域模型使用 UTType 标识符和标准化小写 Scheme 作为稳定身份。应用身份以规范化 URL 和 Bundle ID 组合表示，避免只按显示名称判断。

### 8.3 核心组件

#### `WorkspaceClient`

对 `NSWorkspace` 的最小封装：

- 查询 UTType 或 URL 的默认应用
- 查询兼容应用
- 设置 UTType 默认应用
- 设置 URL Scheme 默认应用
- 获取应用图标和显示信息

生产实现只使用公开 API；测试使用内存 Fake。

#### `AssociationCatalog`

合并内置种子、应用 Bundle 声明和按需 UTType 解析，去重并产生可搜索目录。它不负责读取或修改当前默认应用。

#### `ApplicationInventory`

发现已安装应用，解析 Bundle 元数据并提供 App Explorer 数据。它提供发现结果，不决定候选兼容性。

#### `ChangePlanner`

把用户意图转换为无重复、可审查的原子变更。它是纯逻辑组件，不执行系统写入。

#### `ChangeExecutor`

串行执行计划、收集错误并在末尾重新读取实际状态。它不创建计划，也不决定 UI。

#### `PreferencesStore`

使用 `UserDefaults` 保存语言、固定项目顺序、窗口状态和少量界面偏好。不保存关联状态缓存作为系统真值。

### 8.4 并发和状态

- 页面 ViewModel 在 `MainActor` 上更新 UI。
- 系统查询和元数据解析使用结构化并发。
- 执行器同一时间只允许一个活动计划。
- 页面进入和用户点击刷新时重建相关快照。
- 应用安装或移除通知只在 App 运行期间使缓存失效，不形成后台监控。

## 9. 数据流

### 9.1 读取

```text
页面出现或刷新
→ ViewModel 请求 AssociationCatalog
→ WorkspaceClient 查询当前处理器与候选应用
→ ViewModel 生成不可变页面快照
→ SwiftUI 渲染
```

### 9.2 写入

```text
用户选择目标应用
→ ChangePlanner 生成计划
→ 原生 Sheet 展示计划
→ 用户确认
→ ChangeExecutor 串行调用 NSWorkspace
→ WorkspaceClient 重新读取实际值
→ ChangeReport
→ Sheet 展示结果
→ 页面刷新
```

## 10. 错误处理

错误按用户可行动性分类：

| 类型 | UI 行为 |
|---|---|
| 用户取消系统同意 | 标记该项未更改，允许重试 |
| 目标应用已移除 | 阻止提交，要求重新选择 |
| 无兼容候选 | 显示空状态，保留“选择其他应用…” |
| API 返回错误 | 显示本地化摘要和失败项 |
| API 成功但读回不一致 | 标记“未生效”，不报告成功 |
| 部分成功 | 保留成功项，只允许重试其余项 |
| 目录解析失败 | 跳过无效声明并记录本地诊断，不中断整个目录 |

错误文案不直接暴露不可读的内部错误字符串。诊断详情保留错误域、错误码、关联标识符和目标 Bundle ID，供复制和问题反馈。

## 11. 隐私与安全

- 不需要管理员权限。
- 不启用 App Sandbox，但必须启用 Hardened Runtime。
- 不安装 Helper、Daemon、LaunchAgent 或系统扩展。
- 不读写用户文档内容。
- 不直接编辑其他应用的 Bundle 或系统数据库。
- 不执行 Shell 命令来修改默认应用。
- 不联网，不包含遥测、崩溃上传或账户系统。
- 日志默认只记录关联标识符、Bundle ID、错误码和执行阶段。
- 发布构建必须签名并通过 Apple 公证。

## 12. 本地化

- 使用 String Catalog 管理 Defly 自有文案。
- 支持 `zh-Hans` 和 `en`。
- 首次启动写入 `zh-Hans` 作为显式默认值。
- 设置页切换后立即刷新根视图，无需重启。
- 选择持久保存，下次启动沿用。
- UTType 本地化描述和 App 名称使用系统或应用 Bundle 提供的值。
- 自动化测试校验两种语言的关键文案键完整，无未翻译键回退到标识符。

## 13. 可访问性

- 全部核心流程可只用键盘完成。
- 使用系统控件和语义化标签。
- App 图标旁始终显示 App 名称。
- 成功、警告、失败同时使用图标、文字和辅助功能值。
- 支持 VoiceOver、提高对比度、降低透明度和减少动态效果。
- 主要操作按钮保持至少符合系统默认的命中区域。

## 14. 测试策略

### 14.1 单元测试

- `AssociationCatalog` 合并、去重和分类
- UTType 扩展名与 MIME 解析
- URL Scheme 标准化
- 智能组合展开
- 无效变更剔除
- 计划稳定排序
- 部分成功与读回不一致分类
- 失败项重试计划
- 固定项目序列化
- 中英文 String Catalog 完整性

### 14.2 ViewModel 与 UI 测试

使用 Fake `WorkspaceClient` 覆盖：

- 中文首次启动
- 中英文即时切换与持久化
- 概览和 Advanced 导航
- 搜索、筛选和空状态
- 系统候选与“选择其他应用…”
- Sheet 取消、确认、执行中和结果状态
- 部分失败后只重试失败项
- VoiceOver 标签和键盘焦点顺序

### 14.3 系统集成测试

真实默认应用写入会改变测试机状态，不在普通 CI 中执行。集成测试在专用 macOS 测试用户或可还原虚拟机中运行：

1. 记录测试关联原值。
2. 调用公开 API 设置测试目标。
3. 读回并验证。
4. 在测试清理阶段恢复原值。
5. 若恢复失败，测试明确失败并输出人工恢复说明。

该清理仅属于测试环境，不构成产品的历史回滚功能。

### 14.4 发布检查

- Debug 与 Release 构建成功
- 单元和 UI 测试通过
- 两种语言人工走查
- 浅色、深色、高对比度和降低透明度走查
- 新用户首次启动与系统同意流程走查
- 签名、公证和 DMG 安装验证
- 凭据与隐私数据扫描

## 15. 验收标准

V1 完成必须满足：

1. 新安装首次启动显示中文。
2. 用户可切换 English，界面立即更新且重启后保持。
3. 概览显示内置组合和用户固定项目的实际系统状态。
4. 文件类型页能按 UTType、扩展名和 MIME 搜索。
5. URL 协议页能显示已发现 Scheme 的当前处理器与候选应用。
6. App Explorer 能从应用角度查看关联。
7. 所有写入前都显示原生确认 Sheet。
8. 智能组合的原子写入和解释标签不会混淆。
9. 用户取消不会写入系统。
10. 变更逐项执行，完成后逐项读回验证。
11. 部分失败时可只重试失败项。
12. App 退出后没有 Defly 后台进程。
13. UI 使用系统蓝、平衡毛玻璃、SF Symbols 和真实 App 图标。
14. 降低透明度和减少动态效果设置得到尊重。
15. 生产实现不调用私有 LaunchServices API。

## 16. 参考资料

- [SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps)
- [Apple NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace)
- [Apple 设置 URL Scheme 默认应用](https://developer.apple.com/documentation/appkit/nsworkspace/setdefaultapplication%28at%3Atoopenurlswithscheme%3Acompletion%3A%29)
- [Apple Uniform Type Identifiers](https://developer.apple.com/documentation/uniformtypeidentifiers/)
- [Apple SwiftUI Material](https://developer.apple.com/documentation/swiftui/material)
- [Apple 降低透明度环境值](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency)

## 17. 决策摘要

| 主题 | 已确认决策 |
|---|---|
| 产品模式 | 概览 + Advanced 双层模式 |
| 管理方式 | 纯手动 |
| 常用任务 | 智能组合 |
| 开源方向 | 公开开源，独立分发 |
| 概览定制 | 默认内容 + 用户固定 |
| 写入安全 | 预览后二次确认 |
| Advanced 视角 | 类型/Scheme Explorer + App Explorer |
| 候选应用 | 兼容优先 + 选择其他应用 |
| V1 入口 | GUI，仅保留可复用核心 |
| 视觉方向 | Native Utility |
| 玻璃强度 | 平衡毛玻璃 |
| 概览布局 | 分组式控制中心 |
| Advanced 布局 | 双栏列表 + 检查器 |
| 确认方式 | 原生 Sheet |
| 主题色 | 系统蓝 |
| 图标 | SF Symbols + 真实 App 图标 |
| 本地化 | 中文/English，默认中文 |
