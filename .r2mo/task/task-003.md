---
runAt: 2026-03-16.09-17-39
title: 关于应用中心的应用
---
- 应用中心打开其他应用或其他应用跳转当前应用时能不能去掉提示框？
- 其他应用不在桌面显示，只能走应用中心统一入口，除非在应用中心中配置了：在桌面显示。

## Changes

- 2026-03-27 Team Leader
- 未启用 Team 模式；按要求额外创建 1 个 Worker 做仓库点位梳理，主实现与验证由 Team Leader 完成，避免在同一批 ArkTS / module.json5 文件上并发修改产生冲突。
- 为 `app-center`、`app-monitor`、`app-security`、`app-hello` 新增 `AppBridgeService` 类型的 `AppServiceExtensionAbility`，跨应用打开改成先调用目标应用自己的桥接扩展，再由目标应用自拉起首页，避免继续走普通 UIAbility 的直接跨应用跳转链路。
- `app-monitor`、`app-security`、`app-hello` 的 `module.json5` 已移除桌面 Home skills，默认不再作为桌面主应用显示，只保留 `app-center` 作为桌面统一入口。
- 为 `app-monitor`、`app-security`、`app-hello` 增加隐藏态 `desktop_shortcuts.json` 快捷方式定义，应用中心中新增“在桌面显示 / 隐藏桌面入口”控制，桌面入口显隐通过桥接扩展调用 `shortcutManager.setShortcutVisibleForSelf` 执行。
- 其他三个应用的页面回跳逻辑已切换到桥接扩展方式，返回应用中心或互相跳转时不再直接 `startAbility` 对方首页。
- 四个应用的工程 `compatibleSdkVersion` / `targetSdkVersion` 已统一提升到本机已安装 SDK `HarmonyOS 6.0.2(22)`，以支持本次使用的 `AppServiceExtensionAbility` 与桌面快捷方式能力。
- 已完成验证：`app-center/dev-build.sh`、`app-monitor/dev-build.sh`、`app-security/dev-build.sh`、`app-hello/dev-build.sh` 均构建成功；`app-center/dev-start.sh`、`app-monitor/dev-start.sh`、`app-security/dev-start.sh`、`app-hello/dev-start.sh` 均已安装并拉起成功。
