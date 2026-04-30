---
runAt: 2026-03-16.09-17-42
title: HARNESS-005 模块化代码架构与跨 App 共享机制
author:
---

# HARNESS-005 模块化代码架构与跨 App 共享机制

## 目标

建立 workspace 级的共享代码模块机制，使 AI Agent 可以按模块化方式开发功能，避免各 app 间重复实现相同的基础能力，同时保持每个 app 的独立性。

## 背景

当前各 app 的 ArkTS 代码完全隔离，常见问题：

1. `SoundEffectPlayer.ets` 在每个 app 中各有一份几乎相同的实现。
2. `AppBridgeService.ets` 的通信协议在各个 app 中手动保持一致，容易漂移。
3. 新增一个 app 时，需要重新实现日志工具、偏好存储、路由助手等基础工具。
4. 没有标准化的目录结构约定，每个 app 内部组织方式不一。

## 需求

### 1. 共享 ArkTS 模块层

- 在 workspace 根目录创建 `shared/ets/` 目录，存放跨 app 共享的 ArkTS 代码。
- 首批共享模块：
  - `shared/ets/utils/Logger.ets`：统一日志工具（封装 `hilog`，自动添加 app 标签）。
  - `shared/ets/utils/PreferencesUtil.ets`：偏好存储工具（封装 `@ohos.data.preferences`）。
  - `shared/ets/utils/RouterHelper.ets`：路由助手（封装 `@ohos.router`，支持参数类型安全传递）。
  - `shared/ets/audio/SoundEffectPlayer.ets`：音效播放工具（从 `app-center` 的实现抽取并泛化）。
  - `shared/ets/bridge/AppBridgeClient.ets`：AppBridge 客户端工具（封装 Want 构建和 startAbility 调用）。
  - `shared/ets/bridge/AppBridgeTypes.ets`：跨 app 通信的类型定义（command 枚举、参数接口）。
- 每个 app 的 `oh-package.json5` 中通过 `overrides` 或本地路径引用 `shared/ets/` 下的模块。
- 在 HarmonyOS HAR 包机制可行时，将 `shared/` 改造为 HAR 包，通过 npm-like 依赖引用。

### 2. App 内标准化目录结构

- 定义标准化的 app 内部目录结构规范：
  ```
  entry/src/main/ets/
  ├── entryability/         # Ability 入口
  │   └── EntryAbility.ets
  ├── extensions/           # ExtensionAbility
  │   └── AppBridgeService.ets
  ├── pages/                # 页面组件
  │   ├── Index.ets
  │   └── ...
  ├── components/           # 可复用 UI 组件
  ├── models/               # 数据模型与接口定义
  ├── viewmodels/           # 视图模型（MVVM）
  ├── services/             # 业务逻辑服务
  ├── utils/                # 工具函数
  └── constants/            # 常量定义
  ```
- 不强制要求已有 app 立即重构，但新建 app 必须遵循此结构。
- 更新 `.cursor/rules/60-arkts-coding-standards.mdc` 或新增规则文件记录此规范。

### 3. 共享模块引用机制

- 在 `scripts/common.sh` 中新增 `link_shared_modules()` 函数：
  - 检测 `shared/ets/` 目录存在。
  - 在目标 app 的 `entry/src/main/ets/_shared/` 下创建符号链接指向 `shared/ets/` 的各模块。
  - 在 `.gitignore` 中排除 `entry/src/main/ets/_shared/`。
- 在 `scripts/create-app.sh` 中调用 `link_shared_modules()`。
- 更新 `build-profile.json5` 或 hvigor 配置确保 `_shared/` 下的代码被正确编译。

### 4. 类型安全的跨 App 通信

- `shared/ets/bridge/AppBridgeTypes.ets` 定义标准化的通信协议：
  - `BridgeCommand` 枚举：`OPEN_ENTRY`、`RETURN_TO_CENTER`、`QUERY_STATUS`、`NOTIFY_EVENT`。
  - `BridgeParameters` 接口：`command`、`sourceBundleName`、`sourceAbilityName`、`timestamp`、扩展参数。
  - `BridgeResponse` 接口：`success`、`errorCode`、`message`。
- 所有 app 的 `AppBridgeService.ets` 使用此类型定义。
- 新增 `.cursor/rules/75-cross-app-communication.mdc` 规则文件，规范跨 app 通信模式。

## 验收标准

- `shared/ets/` 包含 6 个共享模块，代码可被各 app 引用。
- 至少 `app-center` 和 `app-hello` 已改为使用 `shared/ets/` 下的 `Logger.ets` 和 `SoundEffectPlayer.ets`。
- `app-center` 和 `app-hello` 的 `./dev-build.sh` 构建通过。
- `scripts/create-app.sh` 创建的新 app 自动链接共享模块。
- 跨 app 通信使用统一的类型定义。

## 影响范围

- 新增：`shared/ets/`（6 个共享模块）、`.cursor/rules/75-cross-app-communication.mdc`
- 修改：`app-center/`、`app-hello/`（改为使用共享模块）、`scripts/create-app.sh`（集成共享模块链接）

## Changes

- 2026-04-30 13:32: Added shared ArkTS modules and adopted shared Logger/SoundEffectPlayer in app-center and app-hello.
  - Files changed: `shared/ets/utils/Logger.ets`, `shared/ets/utils/PreferencesUtil.ets`, `shared/ets/utils/RouterHelper.ets`, `shared/ets/audio/SoundEffectPlayer.ets`, `shared/ets/bridge/AppBridgeClient.ets`, `shared/ets/bridge/AppBridgeTypes.ets`, `.cursor/rules/75-cross-app-communication.mdc`, `app-center/entry/src/main/ets/pages/Index.ets`, `app-hello/entry/src/main/ets/pages/Index.ets`, `scripts/common.sh`, `.gitignore`
  - Verification: `cd app-center && ./dev-build.sh` and `cd app-hello && ./dev-build.sh` passed; `link_shared_modules()` now syncs ignored `_shared` source copies before build because hvigor rejected symlink copying.
