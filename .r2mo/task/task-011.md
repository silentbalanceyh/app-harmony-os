---
runAt: 2026-04-30.14-51-00
title: Harness 工程环境全量缺陷审计
author: Claude
---

# Harness 工程环境全量缺陷审计

> 审计时间: 2026-04-30 | 审计范围: ~/.claude/settings.json, hooks, plugins, OMC, project-memory, LSP, MCP

## P0 — 必须立即修复

### P0-1: API Key 明文硬编码在 settings.json

- **位置**: `~/.claude/settings.json:3`
- **现状**: `ANTHROPIC_API_KEY` 直接写在 JSON 中，明文存储于磁盘
- **风险**: 任何读取该文件的进程/插件/agent 都能获取密钥
- **修复**: 迁移到环境变量或系统 keychain

### P0-2: Security Guard 对 Write/Edit 中的密钥只告警不阻断

- **位置**: `~/.claude/hooks/security-guard.js:62-69`
- **现状**: `SECRET_PATTERNS` 匹配后仅 `console.error`（告警），未输出 `{ decision: 'block' }`
- **风险**: 密钥可以被正常写入文件，安全守卫形同虚设
- **修复**: 将 `break` 改为输出 block decision 并 exit

```javascript
// 当前代码（有缺陷）:
for (const pattern of SECRET_PATTERNS) {
  if (pattern.test(content)) {
    console.error(`[SecurityGuard] Warning: possible secret in ${toolName} operation`);
    break;  // ← 仅告警，不阻断
  }
}

// 应改为:
for (const pattern of SECRET_PATTERNS) {
  if (pattern.test(content)) {
    console.error(`[SecurityGuard] Blocked: possible secret in ${toolName} operation`);
    console.log(JSON.stringify({ decision: 'block', reason: `Secret pattern detected: ${pattern}` }));
    process.exit(0);
  }
}
```

### P0-3: bypassPermissions + allow: ["*"] 双重全开

- **位置**: `~/.claude/settings.json:15-19` 及项目级 `.claude/settings.local.json`
- **现状**: 全局和项目两级都是 `defaultMode: "bypassPermissions"` + `allow: ["*"]`
- **风险**: 结合 P0-2（安全守卫不阻断），等于无任何操作拦截
- **建议**: 至少在项目级收紧对高危操作的管控

---

## P1 — 应尽快修复

### P1-1: 无 ArkTS/ETS LSP 支持

- **现状**: 7 个 LSP 插件全部安装（clangd, gopls, jdtls, pyright, rust-analyzer, swift, typescript），但本项目主要语言是 **ArkTS/ETS**，无任何 LSP 可提供代码智能
- **影响**: 无跳转定义、无引用查找、无 hover 信息、无诊断
- **建议**: 移除不相关的 LSP（减少启动开销），寻找或等待 ArkTS LSP 支持

### P1-2: OMC 版本落后 3 个小版本

- **当前**: `4.10.1`，**可用**: `4.13.5`
- **安装时间**: 2026-03-25，超过一个月未更新
- **影响**: 可能缺少 bug 修复、新 agent、性能改进
- **修复**: `omc update`

### P1-3: OMC project-memory.json 技术栈识别完全错误

- **位置**: `.omc/project-memory.json`
- **现状**: `languages: []`，`frameworks: []`，`packageManager: "npm"`
- **实际**: ArkTS + ArkUI + hvigor，无 npm
- **影响**: 所有依赖 project-memory 做路由的 agent/技能都会走错路径
- **修复**: 手动填充正确的技术栈信息

### P1-4: Session 上下文膨胀，无清理策略

- **现状**: 7 个 JSONL 文件共 ~32MB，最大单文件 11MB
- **影响**: compaction 加载慢、磁盘持续增长
- **建议**: 定期清理 >30 天的旧 session

---

## P2 — 建议修复

### P2-1: 自动记忆系统未初始化

- **位置**: `memory/` 目录存在但无 `MEMORY.md` 索引文件
- **影响**: 跨 session 无法积累项目知识
- **修复**: 初始化 MEMORY.md 并写入基础项目信息

### P2-2: SessionStart hook 的 context 目录不存在

- **位置**: `~/.claude/hooks/context/` 不存在
- **现状**: hook 代码有 `fs.existsSync` 保护，不报错但无任何上下文注入
- **建议**: 创建目录并放入项目相关的上下文 .md 文件

### P2-3: skill-forced-eval.js 是空操作

- **位置**: `~/.claude/hooks/skill-forced-eval.js`
- **现状**: UserPromptSubmit hook 读取 stdin 后仅输出 "Success"，无实际逻辑
- **影响**: 每次 prompt 提交增加 ~100ms 延迟
- **建议**: 要么实现实际逻辑，要么移除

### P2-4: Stop/Notification hook 不管成功失败都播放声音

- **位置**: `~/.claude/settings.json` Stop 和 Notification hook
- **现状**: `afplay -v 3 /Users/lang/zero-cloud/success.mp3` 不区分 stop_reason
- **建议**: 根据 `stop_reason` 或 `input` 内容区分，仅在成功完成时播放

### P2-5: 两个 HUD 插件同时启用

- **位置**: `enabledPlugins` 中 `claude-hud` + `claude-hud-glm` 均启用
- **风险**: 可能导致 statusLine 渲染冲突
- **建议**: 确认是否有冲突，只保留一个

### P2-6: Blocklist 包含测试条目

- **位置**: `~/.claude/plugins/blocklist.json`
- **现状**: `reason: "just-a-test"` 和 `"this is a security test"` 是测试数据
- **建议**: 清理为空列表或填入实际 block 规则

### P2-7: OMC notepad.md 不存在

- **位置**: `.omc/notepad.md`
- **现状**: 缺失，OMC 工作流中的 notepad 读写功能无法使用
- **建议**: 创建空文件初始化

---

## P3 — 低优先级 / 信息性

### P3-1: 所有模型路由到 glm-5.1

- **现状**: Sonnet/Opus/Haiku 全部映射到 `glm-5.1`，通过 `ANTHROPIC_BASE_URL` 转发
- **影响**: OMC 的 model routing（haiku 查询 / sonnet 标准 / opus 架构）完全失效，实际全部相同
- **注意**: 这可能是有意为之（使用自定义网关），但需知晓 agent 编排层无法区分模型能力

### P3-2: session-summary.js / stop-summary.js 信息过少

- **现状**: SessionEnd 仅记录时间戳，Stop 仅记录原因
- **建议**: 扩展或依赖 OMC 的 session tracking

### P3-3: OMC .omc/state/ 下无活跃 session

- **现状**: `sessions/` 目录为空，`checkpoints/` 存在
- **含义**: 之前未成功完成过 OMC 模式（autopilot/ralph/ultrawork 等）
- **可能原因**: PUA 激活后干扰了正常流程

---

## 汇总

| 等级 | 数量 | 关键项 |
|------|------|--------|
| P0 | 3 | API Key 明文、安全守卫不阻断、全权限双开 |
| P1 | 4 | 无 ArkTS LSP、OMC 过期、技术栈识别错误、Session 膨胀 |
| P2 | 7 | 记忆未初始化、context 目录缺失、空 hook、声音干扰、HUD 冲突、blocklist 脏数据、notepad 缺失 |
| P3 | 3 | 模型路由单一、summary 信息少、无 OMC session 历史 |

**最需立即行动**: P0-2（安全守卫不阻断）和 P0-1（API Key 明文）

## Changes

- 2026-04-30 14:51: Remediated Harness/Claude environment audit findings from task-011.
  - Files changed: `~/.claude/settings.json`, `~/.claude/hooks/security-guard.js`, `~/.claude/hooks/skill-forced-eval.js`, `~/.claude/hooks/sound-notify.js`, `~/.claude/hooks/context/harmony-os.md`, `~/.claude/plugins/blocklist.json`, `.claude/settings.local.json`, `.omc/project-memory.json`, `.omc/notepad.md`, `memory/MEMORY.md`
  - Security fixes: removed hardcoded `ANTHROPIC_API_KEY` from settings, changed global/project permissions from bypass mode to default mode, cleared `allow:["*"]`, made Write/Edit secret matches return a block decision, and disabled dangerous-mode prompt skipping.
  - Environment fixes: corrected OMC project memory to ArkTS/ArkUI/HarmonyOS/hvigor, initialized OMC notepad and project memory, added HarmonyOS SessionStart context, silenced/removing the no-op prompt hook path, cleaned test blocklist entries, disabled unrelated LSP plugins and duplicate HUD, and made success sound conditional.
  - Verification: `node --check` passed for modified hooks; JSON parse checks passed for global/project settings, OMC memory, and blocklist; secret Write hook test returned `{ "decision": "block" }`; safe Edit hook test exited 0; `omc --version` returned 4.13.5. Session JSONL cleanup was assessed but not deleted because current-session detection is ambiguous.

- 2026-04-30 15:03: Fixed feedback items P1-2 and P1-4 from the task-011 verification pass.
  - Files changed: `.omc/omc-version.json`, `.r2mo/task/task-011.md`; environment paths updated under `~/.claude/plugins/marketplaces/omc`, `~/.claude/plugins/cache/omc/oh-my-claudecode`, and `~/.claude/projects/-Users-lang-zero-cloud-app-zero-r2mo-apps-app-harmony-os`.
  - P1-2: ran `omc update` and `omc update --force --clean`; verified `omc --version` is `4.13.5` and `omc version` reports package and installed versions as `4.13.5`. Because marketplace `git fetch` timed out on github.com:443, aligned stale local OMC marketplace metadata and active plugin cache to the installed npm package version `oh-my-claude-sisyphus@4.13.5`, and archived the legacy `4.10.1` cache at `/Users/lang/.claude/plugin-archive/omc-task011-20260430-150240`.
  - P1-4: moved the 7 root-level project session JSONL files from `~/.claude/projects/-Users-lang-zero-cloud-app-zero-r2mo-apps-app-harmony-os` to `/Users/lang/.claude/session-archive/app-harmony-os/20260430-145602` and gzip-compressed them; also archived 6 older-than-30-day subagent JSONL files to `/Users/lang/.claude/session-archive/app-harmony-os/20260430-150240-older-than-30d`.
  - Verification: active OMC package/plugin/cache version files now report `4.13.5`; project session root JSONL count is `0`; project session older-than-30-day JSONL count is `0`; project session directory size is reduced to `688K`.
