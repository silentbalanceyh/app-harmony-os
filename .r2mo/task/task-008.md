---
runAt: 2026-03-16.09-17-43
title: HARNESS-006 构建产物管理与缓存优化
author:
---

# HARNESS-006 构建产物管理与缓存优化

## 目标

优化构建流程的产物管理和缓存机制，减少重复构建时间，确保构建产物的一致性和可追溯性，使 Agent 和开发者可以快速迭代而不被构建开销拖慢。

## 背景

当前构建流程存在的问题：

1. 每个 app 的 `build/` 目录包含大量中间产物，占用磁盘空间且无清理机制。
2. 没有构建缓存共享，即使多个 app 使用相同的 SDK 版本和依赖，每次都从头构建。
3. 没有构建产物版本记录，无法回溯某个 HAP 对应的源码状态。
4. `hvigor` 缓存（`.hvigor/`）在 app 间不共享，重复下载依赖。
5. 没有增量构建支持，每次都执行全量 `assembleApp`。

## 需求

### 1. 构建产物目录规范化

- 定义标准化的构建产物输出路径：`app-*/build/outputs/default/` 下存放 HAP 文件。
- 新增 `scripts/clean-build.sh`（和 `.bat`）：
  - `--app <name>`：只清理指定 app 的 build 目录。
  - `--all`：清理所有 app 的 build 目录。
  - `--deep`：同时清理 `.hvigor/` 缓存和 `.deveco-sdk-shim/`。
  - 默认：只清理当前 app 的 build 目录。
- 清理后确保不影响后续构建。

### 2. hvigor 缓存共享

- 将各 app 的 `.hvigor/` 缓存统一指向 workspace 级的共享缓存目录。
- 在 `scripts/common.sh` 中新增 `configure_hvigor_cache()` 函数：
  - 创建 workspace 级 `.hvigor-cache/` 目录。
  - 修改各 app 的 `hvigor/hvigor-config.json5`（如果存在）或通过环境变量设置缓存路径。
  - 确保多 app 并行构建时不产生缓存冲突。

### 3. 增量构建检测

- 在 `scripts/common.sh` 的 `build_named_app()` 中新增增量构建逻辑：
  - 检查源码文件的最后修改时间是否早于 HAP 文件的时间。
  - 如果 HAP 已存在且比源码新，跳过构建（可配置 `--force` 覆盖）。
  - 打印增量/全量构建状态。
- 新增 `--force` 参数支持强制全量构建。

### 4. 构建产物版本记录

- 每次构建成功后，在 `app-*/build/outputs/default/build-info.json` 中记录：
  - `buildTime`：构建时间。
  - `buildMode`：debug/release。
  - `gitCommit`：当前 git commit hash（如果在 git 仓库中）。
  - `gitDirty`：是否有未提交的更改。
  - `sdkVersion`：使用的 SDK 版本。
  - `hapPath`：HAP 文件相对路径。
  - `hapSize`：HAP 文件大小。

### 5. 构建性能度量

- 在 `build_named_app()` 中自动度量构建耗时。
- 构建完成后打印耗时和构建模式。
- 在 `workspace-status.sh` 中增加构建耗时统计。

## 验收标准

- `scripts/clean-build.sh --all` 清理所有 app 的 build 目录，后续构建正常。
- `scripts/clean-build.sh --deep` 额外清理缓存，后续构建正常。
- hvigor 缓存共享配置后，第二个 app 的构建依赖下载时间显著减少。
- 增量构建检测有效：未修改源码时跳过构建。
- `build-info.json` 正确记录每次构建的元信息。
- 构建耗时打印正确。

## 影响范围

- 新增：`scripts/clean-build.sh`、`scripts/clean-build.bat`
- 修改：`scripts/common.sh`（新增缓存配置、增量构建、版本记录逻辑）
- 可能修改：各 app 的 `hvigor/hvigor-config.json5`

## Changes

- 2026-04-30 13:32: Added build cleanup, shared hvigor cache configuration, incremental build checks, build metadata, and duration reporting.
  - Files changed: `scripts/clean-build.sh`, `scripts/clean-build.bat`, `clean-build.sh`, `clean-build.bat`, `scripts/common.sh`, `workspace-status.sh`, `workspace-status.bat`, `.gitignore`, app-level `build-profile.json5` visibility
  - Verification: `./scripts/clean-build.sh --help` and `./clean-build.sh --help` passed; `./workspace-status.sh` showed built HAPs and last durations; builds wrote `build/outputs/default/build-info.json`; `.hvigor-cache/` is ignored.
