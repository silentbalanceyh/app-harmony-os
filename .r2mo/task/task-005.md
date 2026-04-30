---
runAt: 2026-03-16.09-17-41
title: HARNESS-003 一键环境拉起与自愈流水线
author:
---

# HARNESS-003 一键环境拉起与自愈流水线

## 目标

实现"一个命令即可从零拉起完整开发环境"的能力，并在拉起过程中自动检测和修复常见故障，确保 Agent 和人类开发者都能以最低摩擦进入可用状态。

## 背景

当前环境拉起存在以下摩擦点：

1. 首次使用需手动运行 `setup-deveco-config.sh` 或 `setup-environment.ps1` 配置 SDK shim 和 IDE Run Configuration。
2. 模拟器启动失败时，错误信息只写入 `.logs/simulator-start.log`，Agent 不知道去查看。
3. 构建失败时没有自动诊断，Agent 需要人工介入排查。
4. 没有一键"全 app 构建 + 安装 + 启动"的入口。

## 需求

### 1. 一键拉起入口脚本

- 新增根级 `bootstrap.sh`（macOS/Linux）和 `bootstrap.bat`（Windows）。
- 执行流程：
  1. 检测 DevEco Studio 安装 → 未安装则打印安装指引并退出。
  2. 检测 SDK → 未安装则打印 SDK Manager 指引并退出。
  3. 自动调用 `setup-deveco-config.sh` 逻辑配置 SDK shim。
  4. 启动模拟器（复用 `start-simulator.sh`）。
  5. 按依赖序构建并安装所有 app（先 app-center，再子 app）。
  6. 启动 `app-center`。
  7. 打印环境状态摘要：连接的设备、已安装的 bundle、可用 app 列表。
- 幂等设计：已完成的步骤跳过，不影响重复执行。

### 2. 自愈诊断函数

- 在 `scripts/common.sh` 中新增 `diagnose_build_failure()` 函数：
  - 分析 hvigorw 输出，识别常见错误模式：
    - SDK 版本不匹配 → 打印修复建议
    - 模块未找到 → 检查 `oh-package.json5` 和 `build-profile.json5`
    - 签名配置缺失 → 提示配置签名
    - ArkTS 编译错误 → 提取并展示具体行号和错误信息
  - 返回诊断报告供 Agent 或开发者使用。
- 在 `scripts/common.sh` 中新增 `diagnose_runtime_failure()` 函数：
  - 收集 `hilog` 最近的 crash/error 日志。
  - 收集 `bm dump` 确认 bundle 安装状态。
  - 返回诊断报告。

### 3. 构建失败自动重试

- `build_named_app()` 函数在构建失败时自动触发 `diagnose_build_failure()`。
- 如果诊断结果为可自动修复（如 SDK shim 缺失），自动修复并重试一次。
- 不可自动修复的问题打印诊断报告后退出。

### 4. 全 workspace 操作入口

- 新增根级 `workspace-build.sh`、`workspace-start.sh`、`workspace-stop.sh`。
- `workspace-build.sh`：按依赖序构建所有 app（从 `app-center` 开始）。
- `workspace-start.sh`：按依赖序安装并启动所有 app。
- `workspace-stop.sh`：停止所有 hvigor 进程。
- 支持参数：`--app <name>` 只操作指定 app；`--skip <name>` 跳过指定 app。
- Windows 对等 `.bat` 版本。

### 5. 环境状态报告

- 新增 `workspace-status.sh`（和 `.bat`）。
- 输出：DevEco 路径、SDK 版本、连接设备列表、每个 app 的构建状态和安装状态。

## 验收标准

- 在全新机器上（已安装 DevEco Studio和 SDK），运行 `./bootstrap.sh` 可自动完成从 SDK 配置到全 app 启动的完整流程。
- 构建失败时自动输出诊断报告，包含具体错误和建议修复方案。
- `./workspace-build.sh` 可一键构建所有 app。
- `./workspace-status.sh` 输出完整的环境状态摘要。
- 所有脚本幂等，重复执行不出错。

## 影响范围

- 新增：`bootstrap.sh`、`bootstrap.bat`、`workspace-build.sh`、`workspace-build.bat`、`workspace-start.sh`、`workspace-start.bat`、`workspace-stop.sh`、`workspace-stop.bat`、`workspace-status.sh`、`workspace-status.bat`
- 修改：`scripts/common.sh`（新增诊断函数）、`scripts/common.bat`
- 不变：各 `app-*/dev-*.sh` 入口脚本

## Changes

- 2026-04-30 13:32: Added one-command workspace bootstrap/status/build/start/stop scripts and shared build/runtime diagnosis hooks.
  - Files changed: `bootstrap.sh`, `bootstrap.bat`, `workspace-build.sh`, `workspace-build.bat`, `workspace-start.sh`, `workspace-start.bat`, `workspace-stop.sh`, `workspace-stop.bat`, `workspace-status.sh`, `workspace-status.bat`, `scripts/common.sh`, `scripts/common.bat`
  - Verification: `bash -n` passed for all new shell scripts; `./workspace-status.sh` reported DevEco/SDK state, no connected targets, and all six apps; install/start verification was not run because no HarmonyOS target was connected.
