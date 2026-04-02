---
runAt: 2026-03-16.09-17-39
title: 先开发个简单的 app-center 应用中心
---
开发一个应用中心，可直接安装、卸载、呈现、打开基础应用，但是应用中心需要像 iPhone 那种 App 的图标格式排列。

## Changes

- 2026-03-27 Team Leader
- 未启用 Team 模式；本次任务集中在 `app-center` 单应用的 ArkTS 页面与交互实现，拆 Worker 会在同一组页面文件上产生高合并成本。
- 重做 `app-center` 首页为 iPhone 风格的应用图标网格布局，4 个基础应用均以图标、短标签、安装状态的形式在首页呈现。
- 为应用中心增加选中应用详情区，支持查看职责说明、刷新安装状态、打开应用、尝试安装、进入系统应用管理、进入卸载管理入口。
- 安装状态刷新使用设备侧包安装检测完成，页面进入时会自动刷新一次，并展示已安装/待处理数量。
- “打开应用”已接入原生 `startAbility`；“尝试安装”优先走按需安装启动；“卸载管理”走系统应用详情页或应用管理页，避免伪造普通应用无权限执行的静默卸载能力。
- 已完成验证：`app-center/dev-build.sh` 构建成功，`app-center/dev-start.sh` 在模拟器上能够安装并拉起 `app-center`、`app-monitor`、`app-security`、`app-hello`。
- 2026-03-27 Team Leader
- 修正 `app-center/dev-start.sh` 的默认行为：依赖应用仍会自动构建/安装，但不再在最后阶段把 `app-monitor`、`app-security`、`app-hello` 依次拉到前台，避免用户执行应用中心启动脚本后看到的不是应用中心。
- 保留 `launchTargets` 配置作为显式能力；仅当设置 `LAUNCH_DEPENDENCIES=true` 时，`app-center` 才会继续批量拉起其它基础应用。
- 2026-03-27 Team Leader
- 修复 `app-center` 点击后立即退出的问题：设备侧 `faultlog` 明确为 `TypeError: Cannot read property toString of undefined`，定位到 `entry/src/main/ets/pages/Index.ets` 的首页统计区渲染逻辑。
- 将首页的计算属性改为显式方法调用，并补上默认应用兜底，避免 ArkUI 首次渲染阶段把 getter 结果解析为 `undefined` 后导致页面构建崩溃。
- 已完成验证：`app-center/dev-build.sh` 构建成功，`app-center/dev-start.sh` 安装并拉起成功；`aa dump --mission-list` 中 `com.zerows.appcenter` 处于 `FOREGROUND`，且未生成新的 `jscrash` 文件。
