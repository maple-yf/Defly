# Defly

Defly 是一款计划中的原生 macOS 默认应用管理工具，用来查看和修改文件类型、UTType 与 URL Scheme 的默认处理应用。

它参考 [SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps) 的能力范围，但采用独立 App、现代 Apple 公共 API 和更安全的变更确认流程。

## 项目状态

功能与 UI 设计已经确认，App 实现尚未开始。仓库当前用于沉淀产品设计和后续实现。

## 核心体验

- 双层模式：概览页处理常用设置，Advanced 页面提供完整控制。
- 智能组合：例如一次设置默认浏览器时，同时预览 HTTP、HTTPS 和网页文档关联。
- 安全更改：提交前展示旧应用、新应用和全部原子变更，并进行二次确认。
- 结果透明：逐项报告成功或失败，完成后重新读取 macOS 的实际状态。
- 手动管理：不运行菜单栏常驻程序，不后台监控，也不自动恢复设置。
- 原生界面：SwiftUI + AppKit、平衡毛玻璃、系统蓝主题、SF Symbols 和真实应用图标。
- 中英文界面：首次启动默认中文，可在设置中切换 English 并持久保存。

## V1 范围

- 概览页及可自定义固定项目
- 文件类型与 UTType Explorer
- URL Scheme Explorer
- App Explorer
- 兼容应用优先的选择器与“选择其他应用”
- 原生 Sheet 变更预览、确认、执行和失败重试
- 中文与英文界面

V1 不包含后台监控、历史回滚、配置档案、导入导出、菜单栏模式或 CLI。核心逻辑会保持独立，以便未来增加 CLI。

## 技术方向

- Swift、SwiftUI 与少量 AppKit 桥接
- macOS 14 及以上
- `NSWorkspace` 与 `UniformTypeIdentifiers`
- 仅使用公开 API，不直接写 LaunchServices 数据库
- 独立签名与公证的 DMG；Homebrew Cask 可在稳定发布后补充

当前还没有可构建的 Xcode 工程。详细设计见：

- [Defly macOS App 设计规格](docs/superpowers/specs/2026-07-26-defly-macos-app-design.md)

## English

Defly is a planned native macOS utility for viewing and changing default handlers for file types, UTTypes, and URL schemes. The first release will provide a simple overview, advanced explorers, explicit change previews, per-item results, and a Chinese/English interface.

## 开源许可

Defly 计划以开源方式发布。首个公开版本发布前必须由项目所有者选择并加入 OSI 批准的许可证；在许可证加入仓库前，默认版权规则仍然适用。
