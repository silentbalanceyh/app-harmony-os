---
runAt: 2026-04-03.17-09-47
title: 换一种方式
---
app-center 只检查有没安装，不做安装卸载的事，主要是成为桌面看板，而设置中只更改图标、风格呢？

---
## Changes

**Date**: 2026-04-03

### Team Execution
- Team Leader directly executed implementation (no extra workers needed for this scope).

### Implemented
1. **app-center 改为桌面看板模式** (`app-center/entry/src/main/ets/pages/Index.ets`)
   - 入口页只做安装状态检查与展示，不再做安装、卸载、桌面显隐控制。
   - 未安装应用仍显示“未装”角标，但点击不触发安装流程。

2. **设置页改为样式配置页** (`app-center/entry/src/main/ets/pages/Index.ets`)
   - 移除安装按钮、卸载逻辑、桌面显隐开关。
   - 每个应用保留“换风格”按钮，仅修改图标背景与描边风格。
   - 支持 3 套风格循环切换（蓝 / 粉 / 绿）。

3. **图标视觉优化** (`app-center/entry/src/main/ets/pages/Index.ets`)
   - 图标圆角弧度减小（由 `size / 4` 调整为 `size / 5`）。
   - 图标内部 SVG 放大（入口 64 容器内由 36 增至 42）。
   - 描边保留加粗效果，并按应用颜色区分。

4. **验证**
   - `app-center` 构建成功：`BUILD SUCCESSFUL`。
   - 已通过 `./dev-start.sh` 安装并启动到模拟器。
