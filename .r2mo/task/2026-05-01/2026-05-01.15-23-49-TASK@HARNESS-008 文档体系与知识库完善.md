---
runAt: 2026-03-16.09-17-44
title: HARNESS-008 文档体系与知识库完善
author:
---

# HARNESS-008 文档体系与知识库完善

## 目标

完善 workspace 的文档体系，为 AI Agent 和人类开发者提供完整的上下文知识库，确保任何新 session 都能快速理解当前环境状态和开发规范。

## 背景

当前文档体系存在以下缺口：

1. 没有架构决策记录（ADR），重要设计选择的背景和理由没有留存。
2. 没有常见问题排查手册，Agent 遇到问题时需要反复推理。
3. `app.json` 的 schema 没有正式文档，字段含义依赖代码中的使用方式推断。
4. 各 app 的 `REQ.md` 不完整（`app-album` 有但其他 app 没有）。
5. 没有 workspace 级的 CHANGELOG 或版本历史。

## 需求

### 1. 架构决策记录

- 在 `docs/adr/` 目录下创建 ADR 文件，使用标准格式（Status / Context / Decision / Consequences）。
- 首批 ADR：
  - `ADR-001-multi-app-workspace.md`：为什么选择多 app 独立工程而非单工程多模块。
  - `ADR-002-app-center-orchestrator.md`：为什么选择中心编排模式而非去中心化对等模式。
  - `ADR-003-shell-script-harness.md`：为什么选择 Shell 脚本作为 Harness 而非 Node.js/Python 工具链。
  - `ADR-004-shared-ets-modules.md`：为什么选择符号链接共享而非 HAR 包（当前阶段）。
  - `ADR-005-app-json-metadata.md`：为什么选择 `app.json` 作为运行时元数据源而非 `build-profile.json5` 扩展。

### 2. 故障排查手册

- 创建 `docs/troubleshooting.md`，按场景组织：
  - **环境问题**：DevEco 未安装、SDK 缺失、hdc 不可用、模拟器启动失败。
  - **构建问题**：签名缺失、SDK 版本不匹配、ArkTS 编译错误、依赖找不到。
  - **部署问题**：安装失败（签名不匹配）、启动失败（Ability 未注册）、设备断连。
  - **运行时问题**：App 崩溃（faultlog 排查）、跨 app 启动失败（Want 参数错误）、UI 渲染异常。
  - **Agent 特有问题**：ArkTS 语法不支持（对象展开等）、模块引用失败、热重载不生效。
- 每个场景包含：症状描述、根因分析、修复步骤、验证命令。

### 3. app.json Schema 文档

- 创建 `docs/app-json-schema.md`，正式记录 `app.json` 的完整 schema：
  - `app`：app 目录名（如 `app-center`）。
  - `device`：目标设备 ID（空字符串表示默认设备）。
  - `bundleName`：HarmonyOS bundle name。
  - `moduleName`：主模块名（通常为 `entry`）。
  - `abilityName`：主 Ability 名（通常为 `EntryAbility`）。
  - `dependsOn`：依赖的 app 目录名数组。
  - `launchTargets`：可启动的目标 app 目录名数组。
- 包含示例和字段说明。

### 4. 各 App 的 REQ.md 补齐

- 为缺少 `REQ.md` 的 app 创建需求基线文档：
  - `app-center/REQ.md`
  - `app-monitor/REQ.md`
  - `app-security/REQ.md`
  - `app-hello/REQ.md`
  - `app-medication/REQ.md`
- 每个 `REQ.md` 包含：app 定位、核心目标、目标用户、MVP 范围、workspace 集成预期。

### 5. Workspace CHANGELOG

- 创建 `CHANGELOG.md`，记录 workspace 级的重要变更。
- 格式遵循 [Keep a Changelog](https://keepachangelog.com/)。
- 初始条目包含已有的重大变更（从 git 历史推断）。

### 6. 更新规则文件引用

- 更新 `.cursor/rules/40-task-workflow-and-docs.mdc`，增加对 `docs/adr/` 和 `docs/troubleshooting.md` 的引用说明。
- 更新 `AGENTS.md` 的 Session Startup Order，增加"遇到问题时参考 `docs/troubleshooting.md`"。

## 验收标准

- `docs/adr/` 包含 5 个 ADR 文件，格式规范，内容反映实际架构决策。
- `docs/troubleshooting.md` 覆盖 5 大类 20+ 个常见问题场景。
- `docs/app-json-schema.md` 完整记录 `app.json` 的所有字段。
- 5 个 app 的 `REQ.md` 全部创建。
- `CHANGELOG.md` 创建并包含初始条目。
- 规则文件和 `AGENTS.md` 已更新引用。

## 影响范围

- 新增：`docs/adr/`（5 个 ADR）、`docs/troubleshooting.md`、`docs/app-json-schema.md`、`CHANGELOG.md`、5 个 `REQ.md`
- 修改：`.cursor/rules/40-task-workflow-and-docs.mdc`、`AGENTS.md`

## Changes

- 2026-04-30 13:32: Added workspace knowledge-base documentation, ADRs, app schema docs, changelog, and REQ baselines.
  - Files changed: `docs/adr/ADR-001-multi-app-workspace.md`, `docs/adr/ADR-002-app-center-orchestrator.md`, `docs/adr/ADR-003-shell-script-harness.md`, `docs/adr/ADR-004-shared-ets-modules.md`, `docs/adr/ADR-005-app-json-metadata.md`, `docs/troubleshooting.md`, `docs/app-json-schema.md`, `CHANGELOG.md`, `app-center/REQ.md`, `app-monitor/REQ.md`, `app-security/REQ.md`, `app-hello/REQ.md`, `app-medication/REQ.md`, `.cursor/rules/40-task-workflow-and-docs.mdc`, `AGENTS.md`
  - Verification: `rg` confirmed docs/rule references; `docs/troubleshooting.md` contains 25 scenarios across the requested categories; five ADR files and five requested app REQ files are present.
