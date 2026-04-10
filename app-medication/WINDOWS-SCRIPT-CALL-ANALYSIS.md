# Windows 平台 dev 启动脚本调用问题分析

## 问题概述

本机为 Windows 系统，项目存在完整的 `.bat` 脚本体系，但启动 dev 环境时系统调用了 `dev-start.sh` 而非 `dev-start.bat`，导致因 macOS 路径格式报错。

---

## 调用链路分析

### 实际发生的调用链

```
Claude Code 会话启动
  └─ 读取 AGENTS.md (Session Startup Order 第一步)
       └─ AGENTS.md:47 "dev-start.sh must be treated as the primary entry"
       └─ AGENTS.md:63-64 "Build: cd app-center && ./dev-start.sh"
  └─ 读取 CLAUDE.md (Session Startup Order 第二步)
       └─ CLAUDE.md:26 "cd app-center && ./dev-start.sh"
       └─ CLAUDE.md:191 "cd app-medication && ./dev-start.sh"
  └─ 用户请求: "运行dev环境"
       └─ Claude Code 依据文档规则调用: bash dev-start.sh
            └─ dev-start.sh
                 └─ source scripts/common.sh
                      └─ start_dev()
                           └─ ensure_simulator_running()
                                └─ bash $SIMULATOR_SCRIPT (即 ../start-simulator.sh)
                                     └─ macOS 路径报错
```

### 正确的 Windows 调用链（未被使用）

```
用户请求: "运行dev环境"
  └─ Claude Code 应调用: dev-start.bat
       └─ dev-start.bat
            └─ call "%~dp0scripts\common.bat" :start_dev
                 └─ scripts\common.bat :start_dev
                      └─ :ensure_simulator
                           └─ call "%SIMULATOR_SCRIPT%" (即 ../start-simulator.bat)
                                └─ Windows 正确路径
```

---

## 根因定位

### 核心问题文件（强制 .sh 规则）

| 文件 | 行号 | 问题内容 | 影响范围 |
|------|------|----------|----------|
| `AGENTS.md` | 47 | `dev-start.sh must be treated as the primary entry for local development` | 会话首选入口 |
| `AGENTS.md` | 26 | Each app must provide `dev-build.sh`, `dev-start.sh`, `dev-stop.sh` | App 级规则 |
| `AGENTS.md` | 63-64 | Build/Start 示例命令均为 `.sh` | 调试入口指引 |
| `.cursor/rules/10-workspace-structure.mdc` | 13-14 | 与 AGENTS.md 相同规则 | 会话规则加载 |
| `.cursor/rules/30-scripts-and-debug.mdc` | 5 | `First choice is cd <app> && ./dev-start.sh` | 调试规则 |
| `.cursor/rules/30-scripts-and-debug.mdc` | 11-12 | `.sh` 检查模拟器/设备连通性 | 流程规则 |
| `.cursor/rules/30-scripts-and-debug.mdc` | 27-30 | Build/Start/Simulator 示例均为 `.sh` | 调试入口指引 |
| `.cursor/rules/50-app-initialization.mdc` | 32-33, 81-83 | 初始化流程均调用 `.sh` | 新 App 初始化 |

### 文档层面（示例全为 .sh）

| 文件 | 行号 | 内容 |
|------|------|------|
| `CLAUDE.md` | 13 | `Make dev-start.sh enough for most local development workflows` |
| `CLAUDE.md` | 25-26 | Quick Start 示例 |
| `CLAUDE.md` | 177-192 | Build/Start 命令列表（5 个 app 全为 `.sh`） |
| `CLAUDE.md` | 222 | `All per-app scripts delegate to scripts/common.sh` |
| `CLAUDE.md` | 291-292, 307, 376 | 多处引用 `.sh` |
| `README.md` | 43-44, 51-52, 60 | Quick Start 和脚本说明全为 `.sh` |

### 权限配置层面

| 文件 | 配置内容 | 问题 |
|------|----------|------|
| `app-medication/.claude/settings.local.json` | 仅允许 `./dev-start.sh:*` | 未配置 `.bat` 权限 |
| `app-center/.claude/settings.local.json` | 允许 `./dev-start.bat` | ✅ 正确 |
| `app-hello/.claude/settings.local.json` | 允许 `./dev-build.bat`, `./dev-start.bat` | ✅ 正确 |

---

## 调用决策流程图

```
┌─────────────────────────────────────────────────────────────┐
│                  Claude Code 会话启动                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  1. 读取 AGENTS.md                                          │
│     → 强制规则: ".sh 是首选入口"                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  2. 读取 CLAUDE.md                                          │
│     → 所有示例: "./dev-start.sh"                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  3. 读取 .cursor/rules/*.mdc                                │
│     → 规则 10/30/50: 全部引用 .sh                            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  用户请求: "运行dev环境"                                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Claude Code 决策:                                          │
│  • 查找文档规则 → 所有规则指向 .sh                            │
│  • 查找权限配置 → app-medication 仅允许 .sh                   │
│  • 执行: bash dev-start.sh ←───────────────── 错误决策       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  结果: macOS 路径报错                                        │
│  "[ERROR] hdc not found: .../Contents/sdk/..."              │
└─────────────────────────────────────────────────────────────┘
```

---

## 正确的 Windows 调用方式

### 方式一：直接执行 .bat（推荐）

```cmd
cd D:\app-harmony-os\app-medication
dev-start.bat
```

或在 PowerShell 中：
```powershell
cd D:\app-harmony-os\app-medication
.\dev-start.bat
```

### 方式二：使用 cmd.exe 包装

```bash
cmd.exe /c dev-start.bat
```

---

## 现有 .bat 脚本清单

| 脚本 | 路径 | 功能 |
|------|------|------|
| `dev-start.bat` | `app-medication/dev-start.bat` | 构建+安装+启动 |
| `dev-build.bat` | `app-medication/dev-build.bat` | 构建 debug |
| `dev-stop.bat` | `app-medication/dev-stop.bat` | 停止 hvigor 进程 |
| `run-start.bat` | `app-medication/run-start.bat` | Release 启动 |
| `common.bat` | `app-medication/scripts/common.bat` | 共享逻辑（Windows 路径） |
| `start-simulator.bat` | `根目录/start-simulator.bat` | 模拟器启动（Windows 路径） |

---

## .bat 脚本正确性验证

`scripts/common.bat` 第 22-26 行已使用正确的 Windows 路径：

```batch
if not defined DEVECO_STUDIO_PATH set "DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio"
set "DEVECO_HVIGORW=%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.bat"
set "DEVECO_HDC=%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe"
set "DEVECO_SDK_ROOT=%DEVECO_STUDIO_PATH%\sdk\default"
```

**无 `/Contents/` 目录**，直接指向 DevEco 安装根目录。

---

## 问题本质总结

| 层面 | 现状 | 正确期望 |
|------|------|----------|
| 文档规则 | 100% macOS/Linux 视角 | 应区分平台或优先 .bat |
| 权限配置 | `app-medication` 仅允许 .sh | 应同时允许 .bat |
| Claude Code 决策 | 依据文档规则 → 调用 .sh | 应检测平台 → 调用 .bat |

**核心矛盾**：项目已准备好完整的 Windows `.bat` 脚本体系，但所有会话规则、文档、权限配置均未提及，导致 AI Agent 在 Windows 环境下仍按 macOS 规则调用 `.sh`。

---

## 修复建议

### 1. 修改 AGENTS.md

在 App Policy 和 Script Rules 中增加平台检测规则：

```markdown
## Platform-Specific Script Rules

- On Windows (MINGW64/MSYS/CMD), use `dev-start.bat` as primary entry.
- On macOS/Linux, use `dev-start.sh` as primary entry.
- Claude Code should detect `uname -s` output to determine platform.
```

### 2. 修改 .cursor/rules/30-scripts-and-debug.mdc

增加平台分支：

```markdown
## Platform Detection

- Check `uname -s`:
  - `MINGW*` / `MSYS*` / `CYGWIN*` → Windows, use `.bat`
  - `Darwin` / `Linux` → Unix, use `.sh`

## Debug Entry Points (Platform Aware)

- Windows: `cd app-center && dev-start.bat`
- macOS/Linux: `cd app-center && ./dev-start.sh`
```

### 3. 修改 app-medication/.claude/settings.local.json

增加 `.bat` 权限：

```json
{
  "permissions": {
    "allow": [
      "Bash(cmd.exe /c dev-start.bat)",
      "Bash(./dev-start.bat)",
      ...
    ]
  }
}
```

### 4. 修改 CLAUDE.md Quick Start

增加 Windows 章节：

```markdown
## Quick Start (Windows)

```cmd
dev-start.bat
hdc shell hilog -x
dev-stop.bat
```
```

---

## 立即可行的验证方式

在 Claude Code 会话中执行：

```bash
cmd.exe /c "D:\app-harmony-os\app-medication\dev-start.bat"
```

---

## 相关文件索引

| 类别 | 文件 |
|------|------|
| 会话入口规则 | `AGENTS.md`, `.cursor/rules/*.mdc` |
| 项目手册 | `CLAUDE.md`, `README.md` |
| 权限配置 | `app-medication/.claude/settings.local.json` |
| Windows 脚本 | `*.bat` (根目录及各 app) |
| macOS 路径问题 | `start-simulator.sh`, `scripts/common.sh` |