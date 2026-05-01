---
runAt: 2026-03-16.09-17-42
title: HARNESS-004 新 App 脚手架模板与自动化初始化
author:
---

# HARNESS-004 新 App 脚手架模板与自动化初始化

## 目标

提供标准化的 app 脚手架模板和一键初始化工具，使 AI Agent 或开发者可以零摩擦创建一个新的 `app-*` 应用，并自动完成所有注册和配置步骤。

## 背景

当前新建 app 的流程依赖 `50-app-initialization.mdc` 规则文档指导，但实际操作仍需手动：

1. 拷贝最近似 app 的整个目录。
2. 手动修改 `app.json`、`AppScope/app.json5`、`bundleName`、`moduleName`、资源字符串等。
3. 手动在 `app-center/Index.ets` 中添加卡片条目。
4. 手动更新 sibling app 的 `dependsOn`。
5. 手动创建 SDK shim 和 Run Configuration。
6. 清理拷贝产生的临时文件（`.deveco-sdk-shim/`、`.hvigor/`、`build/`）。

这个过程容易遗漏步骤，且 Agent 需要每次重新推理整个流程。

## 需求

### 1. App 模板目录

- 创建 `templates/app-template/` 目录，包含一个最小可运行的 HarmonyOS app 骨架：
  - `AppScope/app.json5`（使用占位 bundleName `com.zerows._appname_`）
  - `entry/src/main/ets/entryability/EntryAbility.ets`（最小 EntryAbility）
  - `entry/src/main/ets/pages/Index.ets`（空白首页）
  - `entry/src/main/module.json5`（标准 entry 模块配置）
  - `entry/src/main/resources/`（占位资源）
  - `build-profile.json5`
  - `oh-package.json5`
  - `hvigorfile.ts`
  - `code-linter.json5`
  - `app.json`（使用占位值）
  - `scripts/common.sh`（薄壳，source workspace 共享层）
  - `scripts/common.bat`（Windows 薄壳）
  - `dev-build.sh`/`dev-start.sh`/`dev-stop.sh`/`run-start.sh` 及 `.bat` 版本
- 模板中所有可变内容使用 `_APP_NAME_`、`_BUNDLE_NAME_`、`_LABEL_` 占位符。

### 2. 初始化工具脚本

- 新增 `scripts/create-app.sh`（和 `.bat`）。
- 参数：`--name <app-name>`（必须以 `app-` 开头）、`--label <中文标签>`、`--template <template-dir>`（可选，默认 `templates/app-template`）。
- 执行流程：
  1. 校验 name 格式（`app-` 前缀、无空格、无特殊字符）。
  2. 校验目标目录不存在。
  3. 复制模板目录到 `app-<name>/`。
  4. 替换所有占位符：`_APP_NAME_` → 实际 app 名，`_BUNDLE_NAME_` → `com.zerows.app<suffix>`，`_LABEL_` → 中文标签。
  5. 清理模板临时文件（`.deveco-sdk-shim/`、`.hvigor/`、`build/`）。
  6. 调用 `setup-deveco-config.sh` 逻辑为新 app 创建 SDK shim 和 Run Configuration。
  7. 在 `app-center/app.json` 中注册新 app（添加到 `dependsOn` 和 `launchTargets`）。
  8. 在 `app-center/entry/src/main/ets/pages/Index.ets` 中添加 ManagedApp 条目（含默认图标和配色）。
  9. 在 `app-center/entry/src/main/resources/` 中添加对应图标资源占位。
  10. 尝试构建新 app 和 app-center，验证成功。
  11. 打印初始化摘要：新 app 路径、bundleName、已注册到 app-center。

### 3. 与 `50-app-initialization.mdc` 对齐

- 更新 `.cursor/rules/50-app-initialization.mdc`，将首选初始化方法从"手动拷贝最近似 app"改为"使用 `scripts/create-app.sh`"。
- 保留手动拷贝作为备选方案（模板不适用时）。

### 4. 模板测试验证

- `scripts/create-app.sh --name app-test --label "测试应用"` 可生成可构建的 app。
- 生成的 app 通过 `cd app-test && ./dev-build.sh` 构建验证。
- `app-center` 构建也通过，且 `Index.ets` 中包含 `app-test` 条目。

## 验收标准

- `templates/app-template/` 包含完整的、可直接实例化的 app 骨架。
- `scripts/create-app.sh --name app-demo --label "演示应用"` 一键生成新 app，无需手动修改任何文件。
- 新 app 和 `app-center` 均可构建通过。
- `50-app-initialization.mdc` 已更新首选方法为 `scripts/create-app.sh`。
- 清理生成的 `app-demo`（或保留作为测试 app）后不影响其他 app。

## 影响范围

- 新增：`templates/app-template/`（完整骨架目录）、`scripts/create-app.sh`、`scripts/create-app.bat`
- 修改：`.cursor/rules/50-app-initialization.mdc`、`app-center/app.json`（运行 create-app 时动态更新）

## Changes

- 2026-04-30 13:32: Added the app template and automated app creation scripts.
  - Files changed: `templates/app-template/`, `scripts/create-app.sh`, `scripts/create-app.bat`, `.cursor/rules/50-app-initialization.mdc`
  - Verification: `bash -n scripts/create-app.sh` and template shell scripts passed; `./scripts/create-app.sh --help` passed; `./scripts/create-app.sh --name app-task006-check --label "验证应用"` generated and registered a disposable app, then the generated app, icon, and app-center registration were cleaned up with no `app-task006-check` residue.
