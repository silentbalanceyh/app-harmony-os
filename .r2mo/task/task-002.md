---
runAt: 2026-04-22.18-00-28
title: 多应用环境的 Harness 框架打造
author:
---
当前环境是一个手机的多应用环境，强化 Harmony OS 开发专用的 Harness 环境工程，补齐缺失的部分，目的：
- 让 AI Agent 专注于需求开发
- 让 AI Agent 规范化并且可实现模块化开发
- 不产生额外的开销，可直接拉起环境（拉起过程中尽可能不出错）
根据上述三个需求书写整体的 Harness 工程的 Plan 到 task-003 - task-010 中

## Changes

- 2026-04-30 22:00: 完成 Harness 工程整体 Plan 设计，写入 task-003 至 task-010。
  - task-003: HARNESS-001 跨应用共享脚手架层抽取 — 将各 app 重复的 common.sh 抽取为 workspace 级共享层，per-app 精简为薄壳
  - task-004: HARNESS-002 Agent 引导规则体系强化 — 新增 4 个 .mdc 规则文件（ArkTS 编码规范、模块边界、工具链使用、代码生成红线）
  - task-005: HARNESS-003 一键环境拉起与自愈流水线 — bootstrap.sh 一键拉起、构建失败自动诊断、workspace 级操作入口
  - task-006: HARNESS-004 新 App 脚手架模板与自动化初始化 — templates/app-template 骨架、scripts/create-app.sh 一键创建新 app
  - task-007: HARNESS-005 模块化代码架构与跨 App 共享机制 — shared/ets/ 共享 ArkTS 模块、标准化目录结构、类型安全跨 app 通信
  - task-008: HARNESS-006 构建产物管理与缓存优化 — 清理脚本、hvigor 缓存共享、增量构建、版本记录
  - task-009: HARNESS-007 Agent 零配置开发体验优化 — 签名自动化、环境预检自愈、文件监听自动构建、结构化错误码
  - task-010: HARNESS-008 文档体系与知识库完善 — ADR、故障排查手册、app.json schema、REQ.md 补齐、CHANGELOG
  - 文件变更: `.r2mo/task/task-003.md` ~ `.r2mo/task/task-010.md`（全部重写 frontmatter title 和正文）

- 2026-04-30 15:35: 完成 Harness 审计实现与补充项落地。
  - Claude settings 备份归档：5 个含高危 hook 的备份移入 `~/.claude/settings-archive/`
  - `app-center/app.json` 修复：dependsOn 和 launchTargets 补齐 app-album 等 5 个子 app
  - `app-album` 文档补齐：AGENTS.md、CLAUDE.md、README.md、.cursor/rules/00、10 均已更新
  - `.cursor/rules/90-code-generation-guardrails.mdc` 新增 LSP/Plugin freshness 标准
  - `dev-preview.sh/.bat` 加入脚本契约：AGENTS.md、10-workspace-structure.mdc、50-app-initialization.mdc
  - 新增 `app-album/REQ.md`
  - 清理 `.omc/state/last-tool-error.json` stale error
  - 新增 `scripts/harness-audit.sh`：6 大审计矩阵（Claude 配置、App Inventory、脚本契约、OMC 状态、Plugin 卫生、REQ.md 覆盖），运行结果 PASS:32 WARN:1 FAIL:0
  - 修复 `scripts/harness-audit.sh` 3 个运行时缺陷：macOS grep -oP 兼容、MCP health cache JSON 结构适配、set -e + pipefail 下 ls 空目录 glob 致死
  - 文件变更: `scripts/harness-audit.sh`, `app-center/app.json`, `app-album/REQ.md`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `.cursor/rules/00-harmony-workspace.mdc`, `.cursor/rules/10-workspace-structure.mdc`, `.cursor/rules/50-app-initialization.mdc`, `.cursor/rules/90-code-generation-guardrails.mdc`
  - 验证: `./scripts/harness-audit.sh` → PASS:32 WARN:1 FAIL:0