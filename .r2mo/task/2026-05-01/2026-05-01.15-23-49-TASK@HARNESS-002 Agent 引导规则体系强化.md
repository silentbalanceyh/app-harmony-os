---
runAt: 2026-04-22.18-00-33
title: HARNESS-002 Agent 引导规则体系强化
author:
---

# HARNESS-002 Agent 引导规则体系强化

## 目标

补齐和强化 `.cursor/rules/*.mdc` 以及 `AGENTS.md`/`CLAUDE.md` 中的 Agent 引导规则，使 AI Agent 在任何 session 启动时能快速定位上下文、遵循规范、避免常见错误，从而专注于需求开发。

## 背景

当前规则体系存在以下缺口：

1. 缺少 ArkTS/ArkUI 编码规范规则 — Agent 可能生成不符合 HarmonyOS 惯例的代码（如使用 `require()`、对象展开运算符、`delete` 操作符等 ArkTS 不支持的语法）。
2. 缺少模块化开发边界规则 — Agent 在修改一个 app 时可能意外影响其他 app。
3. 缺少 Harness 工具链使用规则 — Agent 不清楚何时用 `dev-build.sh` 何时用 hvigorw、如何调试构建失败。
4. 缺少代码生成红线规则 — Agent 可能在生成的代码中引入不安全的模式或不合理的依赖。

## 需求

### 1. ArkTS/ArkUI 编码规范规则

- 新增 `.cursor/rules/60-arkts-coding-standards.mdc`。
- 内容覆盖：
  - ArkTS 禁止语法清单：`require()`、对象展开 `{...obj}`、数组展开 `[...arr]`、`delete` 操作符、`eval()`、动态属性名。
  - 替代方案：ES module import、手动属性构造、`slice()`、赋值 `undefined`。
  - 文件系统 API 限制：不使用 `fs.readTextSync`/`fs.writeTextSync`，使用 `fs.openSync` + `readSync`/`writeSync` + `util.TextDecoder`/`util.TextEncoder`。
  - 命名惯例：文件名 PascalCase（页面）、camelCase（工具类）；组件名 PascalCase；函数名 camelCase。
  - 导入惯例：使用 `import X from '@ohos.module'` 而非 `import * as X`。
  - 状态管理惯例：`@State`、`@Prop`、`@Link` 的使用场景。
  - 手势惯例：使用 `.gesture(LongPressGesture().onAction(...))` 而非 `onLongClick`。

### 2. 模块化开发边界规则

- 新增 `.cursor/rules/70-module-boundaries.mdc`。
- 内容覆盖：
  - 每个 `app-*` 是独立的 HarmonyOS 应用，不可跨 app 引用源码。
  - app 间通信仅通过 Want（startAbility）和 AppServiceExtensionAbility。
  - 修改一个 app 的代码时不可修改其他 app 的代码，除非任务明确要求。
  - `app-center` 是唯一桌面入口，其他 app 不可声明 `entity.system.home` skill。
  - 新增 app 必须通过 `50-app-initialization.mdc` 流程注册到 `app-center`。

### 3. Harness 工具链使用规则

- 新增 `.cursor/rules/80-harness-toolchain.mdc`。
- 内容覆盖：
  - 构建使用 `cd <app> && ./dev-build.sh`，不直接调用 `hvigorw`。
  - 启动使用 `cd <app> && ./dev-start.sh`，不自行组装 hdc install + aa start 命令链。
  - 调试日志使用 `hdc shell hilog -x`，不在代码中添加过多 `console.log`。
  - SDK 环境问题通过 `ensure_sdk_environment` 函数自动处理，不手动设置环境变量。
  - 构建失败排查步骤：检查 hvigorw 路径 → 检查 SDK shim → 检查 build-profile.json5 → 检查 oh-package.json5。
  - Previewer 使用 `./dev-preview.sh [page]`，不需要手动配置。

### 4. 代码生成红线规则

- 新增 `.cursor/rules/90-code-generation-guardrails.mdc`。
- 内容覆盖：
  - 不生成包含硬编码密钥、token、密码的代码。
  - 不生成网络请求代码除非 app.json 或 module.json5 中已声明 `ohos.permission.INTERNET`。
  - 不在 UI 代码中执行耗时同步操作。
  - 不生成绕过 HarmonyOS 权限模型的代码。
  - 不生成引用不存在模块或 API 的代码（先查官方文档）。
  - 文件加密/安全相关代码必须使用 HarmonyOS `@ohos.security.cryptoFramework`，不手写加密算法。

### 5. 更新现有规则文件

- 更新 `.cursor/rules/00-harmony-workspace.mdc` 的 Topic File Map，增加 `60-`、`70-`、`80-`、`90-` 四个条目。
- 更新 `AGENTS.md` Session Startup Order，增加新规则文件的加载步骤。
- 更新 `CLAUDE.md` MDC Integration 章节，增加新规则文件说明。

## 验收标准

- 新增 4 个 `.mdc` 规则文件，文件名和内容符合上述规范。
- `00-harmony-workspace.mdc` 的 Topic File Map 包含新增的 4 个条目。
- `AGENTS.md` 的 Session Startup Order 包含新规则加载步骤。
- `CLAUDE.md` 的 MDC Integration 章节包含新规则文件说明。
- 规则内容足以让 AI Agent 避免常见的 ArkTS 语法错误和跨模块边界问题。

## 影响范围

- 新增：`.cursor/rules/60-arkts-coding-standards.mdc`、`.cursor/rules/70-module-boundaries.mdc`、`.cursor/rules/80-harness-toolchain.mdc`、`.cursor/rules/90-code-generation-guardrails.mdc`
- 修改：`.cursor/rules/00-harmony-workspace.mdc`、`AGENTS.md`、`CLAUDE.md`

## Changes

- 2026-04-30 13:32: Added the extended Agent rule set and updated early-load documentation.
  - Files changed: `.cursor/rules/60-arkts-coding-standards.mdc`, `.cursor/rules/70-module-boundaries.mdc`, `.cursor/rules/80-harness-toolchain.mdc`, `.cursor/rules/90-code-generation-guardrails.mdc`, `.cursor/rules/00-harmony-workspace.mdc`, `AGENTS.md`, `CLAUDE.md`, `app-album/entry/src/main/module.json5`, `app-medication/entry/src/main/module.json5`
  - Verification: `rg` confirmed the new rule files are referenced by `AGENTS.md`, `CLAUDE.md`, and `00-harmony-workspace.mdc`; only `app-center` now declares `entity.system.home`; `cd app-album && ./dev-build.sh` and `cd app-medication && BUILD_FORCE=true ./dev-build.sh` passed after removing child desktop-entry skills.
