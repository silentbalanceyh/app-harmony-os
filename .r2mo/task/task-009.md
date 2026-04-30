---
runAt: 2026-03-16.09-17-44
title: HARNESS-007 Agent 零配置开发体验优化
author:
---

# HARNESS-007 Agent 零配置开发体验优化

## 目标

优化开发体验，使 AI Agent 可以在没有人类介入的情况下完成从环境准备到代码修改到验证的完整闭环，消除所有需要人工干预的断点。

## 背景

当前 Agent 开发流程中仍存在以下需要人工介入的场景：

1. 首次使用需要人类运行 `setup-deveco-config.sh`。
2. 签名配置需要在 DevEco Studio GUI 中手动设置。
3. 模拟器创建需要在 DevEco Studio GUI 中操作。
4. 构建失败时，部分错误（如签名缺失）需要人类在 IDE 中修复。
5. 代码修改后没有自动热重载，需要手动重新构建部署。

## 需求

### 1. 签名配置自动化

- 在 `scripts/common.sh` 中新增 `ensure_signing_config()` 函数：
  - 检查 `build-profile.json5` 中的 `signingConfigs` 是否已配置。
  - 如果未配置且存在调试签名证书，自动配置为调试签名。
  - 如果不存在签名证书，自动生成调试签名（使用 HarmonyOS 提供的证书工具）。
  - 在 `build_named_app()` 中自动调用 `ensure_signing_config()`。
- 更新 `.cursor/rules/80-harness-toolchain.mdc` 记录签名自动化行为。

### 2. 环境预检与自动修复

- 在 `scripts/common.sh` 中新增 `preflight_check()` 函数，在每次 `dev-start.sh` 执行前运行：
  - DevEco Studio 路径是否有效 → 否则打印安装指引。
  - SDK 是否已安装 → 否则打印 SDK Manager 指引。
  - SDK shim 是否已创建 → 否则自动调用 `ensure_sdk_environment()`。
  - 模拟器/设备是否连接 → 否则自动调用 `ensure_simulator_running()`。
  - 签名是否已配置 → 否则自动调用 `ensure_signing_config()`。
  - `hdc` 是否可用 → 否则尝试从 DevEco 路径发现。
  - `hvigorw` 是否可用 → 否则尝试从 DevEco 路径发现。
- 每个检查项结果以 `[OK]`/`[FIX]`/`[FAIL]` 标注，`[FIX]` 表示已自动修复，`[FAIL]` 表示需要人工介入。
- 所有 `[FAIL]` 项汇总后以统一的 Action Required 格式输出，方便 Agent 读取。

### 3. 代码修改后自动验证

- 新增 `scripts/watch-build.sh`（和 `.bat`）：
  - 监听指定 app 的 `entry/src/main/ets/` 目录变化（使用 `fswatch` 或 `inotifywait`）。
  - 检测到文件变化后自动触发增量构建。
  - 构建成功后自动安装到设备。
  - 可选：自动重启 app 以加载新代码。
  - 支持参数：`--app <name>`、`--no-restart`（只安装不重启）。
- 如果 `fswatch`/`inotifywait` 不可用，降级为定时轮询模式（每 5 秒检查文件修改时间）。

### 4. Agent 友好的错误输出

- 所有脚本在错误时输出结构化的错误信息：
  - 格式：`[ERROR_CODE] message | suggestion`
  - 错误码枚举：`ENV_001`（DevEco 未安装）、`ENV_002`（SDK 缺失）、`ENV_003`（设备未连接）、`BUILD_001`（构建失败）、`BUILD_002`（签名缺失）、`DEPLOY_001`（安装失败）、`DEPLOY_002`（启动失败）。
  - Agent 可通过解析错误码自动采取对应措施。
- 在 `.cursor/rules/80-harness-toolchain.mdc` 中记录错误码清单。

### 5. DevEco Previewer 无头模式

- 探索 DevEco Previewer 是否支持 CLI 启动（而非 GUI）。
- 如果支持，在 `scripts/common.sh` 中新增 `start_previewer()` 函数，让 Agent 可以在无 GUI 环境下验证 UI 变更。
- 如果不支持，在 `80-harness-toolchain.mdc` 中明确记录此限制。

## 验收标准

- `ensure_signing_config()` 在未配置签名时自动生成调试签名，构建不再因签名缺失而失败。
- `preflight_check()` 输出结构化的预检报告，所有可自动修复的项显示 `[FIX]`。
- `scripts/watch-build.sh` 可监听文件变化并自动构建安装。
- 脚本错误输出包含错误码和建议，Agent 可解析。
- Agent 在不依赖人类的情况下完成"环境预检 → 代码修改 → 构建验证"全流程。

## 影响范围

- 新增：`scripts/watch-build.sh`、`scripts/watch-build.bat`
- 修改：`scripts/common.sh`（新增签名自动化、预检、错误码逻辑）、`.cursor/rules/80-harness-toolchain.mdc`

## Changes

- 2026-04-30 13:32: Added Agent-friendly preflight, signing detection, structured error codes, watch-build scripts, and Previewer CLI limitation reporting.
  - Files changed: `scripts/common.sh`, `scripts/common.bat`, `scripts/watch-build.sh`, `scripts/watch-build.bat`, `watch-build.sh`, `watch-build.bat`, `.cursor/rules/80-harness-toolchain.mdc`
  - Verification: `bash -n` passed for watch/common scripts; builds print `[BUILD_002]` signing guidance when signingConfigs are empty; `cd app-center && ./dev-build.sh`, `cd app-hello && ./dev-build.sh`, `cd app-album && ./dev-build.sh`, `cd app-medication && BUILD_FORCE=true ./dev-build.sh`, and `cd app-monitor && ./dev-build.sh` passed. `app-security` build was stopped after hanging at hvigor daemon startup with no source error in `.logs/app-security-build.log`.
