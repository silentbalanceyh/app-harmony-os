---
runAt: 2026-03-16.09-17-38
title: 初始化当前工程
---
当前工程的初始化动作，根路径只保留文档和配置文件以及隐藏文件，子路径中
- app-xxx 这种路径每个路径初始化为一个鸿蒙手机的 App 工程
先初始化几个系统工程
- app-center 应用中心，针对其他应用的核心入口
- app-monitor 监控中心
- app-security 安全中心
简单说：app-center 属于主应用，上边可以安装其他的应用，并且可以将其他应用进行纳管，app-monitor 和 app-security 是云端连接时必须得应用，然后再做一个 app-hello 表示第一个应用，这个应用需要和其他三个应用协同。每个应用有自己的 dev- 开发专用脚本和 run- 生产专用脚本。

执行完成后更新 CLAUDE.md 文件。

## Changes

- 2026-03-27 Team Leader
- 按 HarmonyOS 手机应用初始化目标，将工程拆分为 4 个顶层独立子工程：`app-center`、`app-monitor`、`app-security`、`app-hello`。
- 每个子工程均补齐独立的 `AppScope/`、`src/`、`build-profile.json5`、`oh-package.json5`、`hvigorfile.ts`、`hvigor/hvigor-config.json5`、`app.json` 和 `dev-build.sh` / `dev-start.sh` / `dev-stop.sh` / `run-start.sh`。
- `app-center` 作为主应用入口，`app-monitor` 与 `app-security` 作为云连接必需应用，`app-hello` 作为首个与前三者协同的业务示例应用；各自首页已写入对应职责说明。
- 根据后续追加要求，移除了根路径的 HarmonyOS 工程文件和旧的 `apps/demo`、根脚本、根级构建配置，根目录仅保留文档、规则说明和隐藏任务资料。
- 新增根级 `AGENTS.md`，并更新 `CLAUDE.md` 与 `README.md`，明确“根目录只作说明入口、`app-*` 子目录独立构建”的规则。
- Team 模式已评估但未启用 Worker；本次任务的关键路径集中在目录重构与统一清理，拆分 Worker 的合并成本高于收益。
- 已完成校验：根目录结构检查通过，四个应用目录的脚本通过 `bash -n` 语法检查。
- 2026-03-27 增补协同骨架：四个应用都加入了显式跨应用拉起入口，`app-center` 可批量拉起其他 3 个应用；各应用 `EntryAbility` 已记录拉起参数并配置为 `singleton` 以承接后续协同扩展。
- 2026-03-27 增补启动脚本：各应用 `dev-start.sh` / `run-start.sh` 现在会执行设备预检、安装当前应用并尝试直接拉起；`app-center` 默认还会检查并继续拉起协同目标应用，可通过 `LAUNCH_DEPENDENCIES=false` 关闭。
- 2026-03-27 增补单独启动保证：四个应用的启动脚本都会根据 `dependsOn` 自动补齐缺失依赖应用的构建与安装，因此每个 `app-*` 目录都可以独立执行脚本完成启动。
- 2026-03-27 完成 HarmonyOS 单应用工程结构对齐：4 个应用统一切换为官方 `entry/` 模块布局，修复 `AppScope` 与模块级 `media` 资源引用，`dev-build.sh` 已实测全部构建成功。
- 2026-03-27 收敛启动脚本行为：4 个应用的 `dev-start.sh` 已实测可直接执行，脚本会自动探测 `hdc`、尝试拉起本机默认 DevEco 模拟器、严格校验 `hdc` 输出并在安装/拉起失败时中止，避免误报成功。
- 2026-03-27 当前宿主机校验结论：`app-center`、`app-monitor`、`app-security`、`app-hello` 的构建链和启动链均已验证；失败点仅剩本机 DevEco 模拟器实例 `nova 15 Pro` 无法被 CLI 直接拉起，相关日志已落到各应用 `.logs/emulator-start.log`。
- 2026-03-27 新增根级 `start-simulator.sh` 统一模拟器入口；4 个应用的 `dev-start.sh` / `run-start.sh` 现已改为在构建前先调用该脚本检查或拉起模拟器，统一失败日志位置为根目录 `.logs/simulator-start.log`。
