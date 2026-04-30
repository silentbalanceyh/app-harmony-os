---
runAt: 2026-04-22.18-00-30
title: HARNESS-001 跨应用共享脚手架层抽取
author:
---

# HARNESS-001 跨应用共享脚手架层抽取

## 目标

将当前各 `app-*/scripts/common.sh` 重复的公共逻辑抽取到 workspace 级共享层，使 AI Agent 新建 app 时可直接复用，无需拷贝粘贴脚本。

## 背景

当前每个 `app-*` 目录各有独立的 `scripts/common.sh`（约 500 行），内容几乎完全一致：日志函数、app.json 读取、hdc 封装、hvigor 发现、SDK shim 构建、依赖检查、构建/部署/启动流程等。新增 app 时需完整复制此文件并微调，极易产生版本漂移。

## 需求

### 1. 共享脚本层

- 在 workspace 根目录创建 `scripts/` 目录，存放所有 app 共用的 shell 逻辑。
- `scripts/common.sh` 包含：日志工具（info/warn/error/ok）、app.json 读写工具、hdc 封装（run_hdc/run_hdc_checked/list_connected_targets 等）、hvigor 发现与调用、SDK 环境搭建（ensure_sdk_environment）、设备连接检查、构建/部署/启动函数。
- `scripts/simulator.sh` 将根目录 `start-simulator.sh` 的核心逻辑提取为可 source 的函数库，供各 app 的 `dev-start.sh` 和根级 `start-simulator.sh` 共用。
- `scripts/app-metadata.sh` 封装 app.json 的 schema 读取与校验逻辑。

### 2. Per-App 薄壳

- 每个 `app-*/scripts/common.sh` 精简为 5–10 行：source workspace 共享层 + 设定 `APP_ROOT`/`APP_CONFIG` 变量 + 调用 `register_app`。
- 保留每个 app 对自身 `app.json` 的直接引用能力。
- 保留 per-app 覆盖点：app 可在自身 `scripts/` 下放置 `overrides.sh`，共享层在关键节点 source 它（如果存在）。

### 3. 向后兼容

- 现有 `dev-build.sh`、`dev-start.sh`、`dev-stop.sh`、`run-start.sh` 入口脚本签名不变。
- 现有 `app.json` schema 不变。
- 迁移后所有 app 的 `./dev-build.sh` 和 `./dev-start.sh` 行为与迁移前完全一致。

### 4. Windows 对等

- `scripts/common.bat` 同步抽取共享层。
- 每个 `app-*/scripts/common.bat` 精简为等价的薄壳。

## 验收标准

- `scripts/common.sh` 包含所有原有公共函数。
- 所有 6 个 app 的 `scripts/common.sh` 精简至 10 行以内且功能不退化。
- `cd app-center && ./dev-build.sh` 构建通过。
- `cd app-center && ./dev-start.sh` 能正常走完流程（在有设备的情况下）。
- 新建一个 app 时只需创建 `scripts/common.sh` 薄壳，无需复制 500 行公共逻辑。

## 影响范围

- 新增：`scripts/common.sh`、`scripts/simulator.sh`、`scripts/app-metadata.sh`、`scripts/common.bat`、`scripts/simulator.bat`、`scripts/app-metadata.bat`
- 修改：所有 `app-*/scripts/common.sh`、所有 `app-*/scripts/common.bat`
- 不变：`app-*/app.json`、`app-*/dev-*.sh` 入口脚本签名

## Changes

- 2026-04-30 13:32: Extracted the shared HarmonyOS harness script layer and converted app-local common scripts to thin wrappers.
  - Files changed: `scripts/common.sh`, `scripts/app-metadata.sh`, `scripts/simulator.sh`, `scripts/common.bat`, `scripts/app-metadata.bat`, `scripts/simulator.bat`, `start-simulator.sh`, `start-simulator.bat`, `app-*/scripts/common.sh`, `app-*/scripts/common.bat`, `.gitignore`
  - Verification: `bash -n` passed for shared/root/app shell scripts; `cd app-center && ./dev-build.sh` passed; `cd app-monitor && ./dev-build.sh` passed; app-local common.sh wrappers are 7 lines and common.bat wrappers are 6 lines.
