---
runAt: 2026-04-20.08-58-13
title: 手机界面设计
author:
---
- 方角代替圆角（内部）
- 使用更加符合企业App的风格，比如少边框，用背景色
- 先按照这种方式调整：应用中心

## Changes

- **app-center/entry/src/main/ets/pages/Index.ets**
  - 移除图标边框（`border({ width: 2, color, radius })`），仅保留背景色区分
  - 应用图标 `borderRadius` 从 `size/5` 改为 `4`（方角风格）
  - 设置页列表项 `borderRadius` 从 `16` 改为 `4`
  - Tab 按钮 `borderRadius` 从 `10` 改为 `4`
  - "换风格"按钮 `borderRadius` 从 `999`(全圆) 改为 `4`
  - 未安装标签 `borderRadius` 从 `999` 改为 `2`
  - 移除标题栏下方的 `Divider` 分隔线，改用 padding 间距
  - 整体风格：方角 + 无边框 + 背景色区分，符合企业 App 设计规范