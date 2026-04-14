# 用药提醒APP·语音交互优化流程
# 优化核心思路

1. 播报结束加**震动提示**，明确告知用户可说话

2. 录音带**头部缓冲**，防止抢话丢字

3. 全程话术统一、节奏稳定，老人也能听懂

4. 技术侧固定VAD参数，避免开头丢字

5. 补充：ASR纠错映射（241393条）为临时堵坑方案，**语音引擎调优为治本核心**，同步落地调优方案，彻底解决识别丢字、误识别问题
    

# 一、完整优化后交互时序流程

## 1）添加药品名称环节

1. 系统语音播报：**请说药品名**

2. 播报结束 → 麦克风动画显示 → **震动提示**

3. 用户说出药品名称

4. 系统语音回复：**好的，XXX药品名**


## 2）设置每日用药次数环节

1. 系统语音播报：**一天吃几次**

2. 播报结束 → 麦克风动画显示 → **震动提示**

3. 用户回答次数

4. 系统语音回复：**好的，一天X次**


## 3）设置单次用药剂量环节

1. 系统语音播报：**一次吃多少**

2. 播报结束 → 麦克风动画显示 → **震动提示**

3. 用户回答剂量

4. 系统语音回复：**好的，一次X片/颗**


## 4）完整复述确认环节

1. 系统语音播报：**已为您设置用药提醒**

2. 系统语音复述：**药品名：XXX，一天X次，一次X片/颗**

3. 系统语音播报：**请问是否确认保存？**

4. 播报结束 → 麦克风动画显示 → **震动提示**

5. 用户回答”确认/取消”

6. 系统执行保存或重新设置
    

# 二、语音引擎调优方案

## 1. 调优核心目标

- 彻底解决：语音播报结束后，用户立即说话时**开头1-2字识别不到**的问题
    
- 辅助解决：药品名、剂量（片/颗/毫升）、次数（1次/2次）等场景化语音误识别问题
    
- 配合ASR纠错映射（241393条），实现“堵坑+治本”双重保障，提升识别准确率至98%以上
    

## 2. 具体调优措施

1. **ASR识别引擎参数调优（核心）**
    
    1. 调整前端点检测（VAD_START）：由原有默认值调整为**600ms**，延长起始静音判定时间，避免将用户开头轻声、气音、半发音判定为静音截断（解决丢字核心）
        
    2. 后端点检测（VAD_END）：保持800ms~1000ms，确保用户说完后正常停止识别，不遗漏结尾内容
        
    3. 开启“弱语音增强”功能：针对老人、轻声说话用户，增强语音信号增益，提升开头弱发音的识别率
        
    4. 降低“噪音抑制”强度：避免过度抑制环境噪音时，误吞用户开头语音（适配居家、户外等常见用药场景）
        
2. **场景化语料训练（贴合用药场景）**
    
    1. 导入用药场景专属语料库：包含常见药品名（西药、中成药）、剂量表述（1片、2颗、0.5毫升）、次数表述（1次、2次、3次/天），共计不少于5000条场景化语料，供引擎针对性训练
        
    2. 重点训练“短语音识别”：适配本APP交互场景（用户回答均为1-5字短语音），优化短语音识别模型，提升短语音开头字的捕捉能力
        
    3. 加入“抢话场景”模拟训练：模拟用户在播报结束后立即说话、抢话的场景，训练引擎对“播报尾音+用户开头语音”的区分能力，避免播报尾音干扰用户语音识别
        
3. **引擎与APP交互时序联动调优**
    
    1. 引擎与APP录音模块同步：APP播报结束、提示音响起时，引擎立即进入“识别就绪”状态，取消原有100ms延迟，同时保留录音头部缓冲（200ms），双重保障不丢字
        
    2. 优化引擎识别响应速度：将识别响应时间压缩至300ms以内，避免用户等待过久重复说话，减少二次识别时的丢字概率
        
4. **纠错映射与引擎联动**
    
    1. 将24139条ASR纠错映射数据同步至语音引擎，作为辅助识别参考，当引擎识别结果匹配纠错映射中的错误案例时，自动触发纠错，提升识别准确率
        
    2. 定期更新引擎语料：每月将APP实际使用中出现的丢字、误识别案例，补充至引擎训练语料库，持续优化识别效果
        

## 3. 调优执行节奏

1. 第一阶段：完成ASR引擎参数调整（VAD、语音增强、噪音抑制），同步联动APP录音模块，解决核心丢字问题
    
2. 第二阶段：导入用药场景语料库，完成场景化训练和抢话场景模拟训练
    
3. 第三阶段：同步ASR纠错映射数据，完成引擎与APP的联动调试
    
4. 第四阶段：测试验证，针对丢字、误识别场景进行批量测试，确保识别准确率达标
    

## 4. 验收标准（实现后验证）

- 核心指标：播报结束后用户立即说话，开头1-2字识别率≥98%，无丢字现象
    
- 辅助指标：药品名、剂量、次数识别准确率≥99%，误识别率≤1%
    
- 场景指标：居家、轻微噪音（电视声、说话声）环境下，识别效果无明显下降
    

# 三、必须同步配置的技术优化点

1. **播报期间提前开启录音缓存**
    
    1. 人声播报过程中就启动录音并缓存，播报结束后将整段音频送入ASR，避免用户抢话丢前几个字。
        
2. **VAD前端点超时（起始静音）调整**
    
    1. 前端点超时：**500ms**（与引擎调优参数联动，以引擎调优600ms为准，此处同步匹配）
        
    2. 后端点超时：**800ms~1000ms**
        
    3. 避免把开头轻声、气音判定为静音截断。
        
3. **提示方式规范**

    1. 震动：短促震动提示，时长**150ms**

    2. 时序：震动必须在**ASR启动之前完成**，避免震动声被麦克风捕获

    3. 视觉：震动同时显示麦克风动画和”请说话”提示文字
        
4. **录音启动时机**
    
    1. 提示音响起时，正式激活ASR识别，同时配合麦克风动画，形成统一反馈。
        

# 四、界面视觉配合

- 每次等待用户说话时：屏幕中间大字显示：**请说话**

- 麦克风图标持续闪烁，直到用户开始说话。


---

# 变更记录

## 2026-04-06 实现

### 已完成项

1. **VAD参数调优** ✅
   - `VoiceService.ets` 添加 VAD 参数常量：
     - `VAD_BEGIN_MS = 600`（前端点检测，解决开头丢字）
     - `VAD_END_MS = 1000`（后端点检测，确保说完再结束）
     - `RECORD_HEAD_BUFFER_MS = 200`（录音头部缓冲）
   - ASR `startListening` 参数已更新

2. **震动提示** ✅
   - 播报结束后震动150ms提示用户
   - 时序调整：**震动在ASR启动之前完成**，避免震动声被识别
   - 界面提示文字改为”请说话”

3. **麦克风动画 + 提示文字** ✅
   - `Index.ets` 添加状态变量：
     - `showMicAnimation`：控制麦克风图标显示
     - `showBeepHint`：控制”听到滴声后再说”提示文字
   - `build()` 方法添加麦克风动画覆盖层

4. ~~**完整确认流程**~~ ❌ **已删除（过度设计）**
   - 原需求无确认步骤，已移除

### 修改文件

| 文件 | 变更说明 |
|------|---------|
| `entry/src/main/ets/services/VoiceService.ets` | VAD参数调优 |
| `entry/src/main/ets/pages/Index.ets` | 震动时序调整、提示文字改为"请说话"、剂量纠错（二颗/二粒/二片） |
| `entry/src/main/ets/services/MedicineDatabase.ets` | 拼音首字母模糊匹配、剂型优先匹配 |
| `entry/src/main/ets/services/MedicineLoader.ets` | UTF-8解码修复（util.TextDecoder） |

### 问题修复记录

#### 问题1：用户没说话ASR就结束识别
- **原因**：VAD 参数设置过短，环境噪音被误判为语音
- **解决**：
  - `vadBegin = 5000ms`（等待用户开始说话的超时时间）
  - `vadEnd = 1500ms`（用户说完后的等待时间）

#### 问题2：震动声音被ASR识别
- **原因**：ASR 启动时震动正在进行，麦克风捕获到震动声
- **解决**：调整时序
  - **之前**：TTS播报 → 震动 → 等待 → 启动ASR
  - **现在**：TTS播报 → 启动麦克风动画 → 震动 → 等待200ms → 启动ASR
  - 核心原则：**震动在 ASR 启动之前完成**

#### 问题3：提示音"滴"被ASR识别（已弃用声音提示）
- **原因**：提示音播放时 ASR 已启动
- **最终方案**：改用震动提示代替声音提示，避免音频干扰

#### 问题4：ASR把"两颗"识别成"二颗"
- **原因**：ASR常见误识别
- **解决**：在 `parseDosageFromText` 添加纠错逻辑，"二颗"→"2颗"，"二粒"→"2粒"

#### 问题5：复方丹参片识别成放单身片
- **原因**：拼音首字母精确匹配，"放单身片"(fdsp) ≠ "复方丹参片"(ffdsp)
- **解决**：拼音首字母改为模糊匹配，支持子串包含匹配

#### 问题6：5粒识别成一片
- **原因**：ASR严重误识别
- **解决**：添加"五例""武力"等常见误识别纠错规则

#### 问题7：药品名称匹配结果显示乱码（å¤æ¹ä¹åç）
- **原因**：`MedicineLoader.ets` 读取 rawfile JSON 时，使用 `String.fromCharCode` 逐字节转换，UTF-8 中文需要3字节编码，导致乱码
- **解决**：使用 `util.TextDecoder` 正确解码 UTF-8
  ```typescript
  import util from '@ohos.util';
  const decoder = util.TextDecoder.create('utf-8');
  const text = decoder.decodeToString(uint8Array);
  ```

#### 问题8：说"一次2颗"显示成"二颗"
- **原因**：纠错逻辑直接返回"2颗"，丢失了"一次"前缀
- **解决**：改为替换而非返回，保留文本前缀
  ```typescript
  // 之前：return '2颗';（丢失前缀）
  // 现在：text = text.replace('二颗', '2颗');（保留前缀）
  ```

#### 问题9：说"复方丹参片"识别成"复方丹参丸"
- **原因**：药品库中"复方丹参丸"排在"复方丹参片"前面，拼音匹配返回第一个匹配项
- **解决**：添加剂型优先匹配逻辑
  ```typescript
  // 如果用户输入包含"片"/"丸"等剂型，优先返回相同剂型的药品
  if (cleaned.endsWith('片')) {
    const formMatch = pinyinMatches.find(m => m.name.endsWith('片'));
    if (formMatch) return formMatch;
  }
  ```

### 待完成项（需外部支持）

1. **ASR引擎调优** - 需用户方提供调优方案
2. **场景化语料训练** - 需引擎团队配合
3. **播报期间提前录音缓存** - 需进一步调研 HarmonyOS ASR API

---

## 2026-04-10 平台检测规则修复

### 问题背景

本机为 Windows 系统，项目已存在完整的 `.bat` 脚本体系，但 Claude Code 会话启动时依据文档规则调用 `dev-start.sh`（macOS 路径格式），导致报错：

```
[ERROR] hdc not found: .../Contents/sdk/default/openharmony/toolchains/hdc
```

### 根因分析

| 层面 | 问题 | 影响 |
|------|------|------|
| `AGENTS.md` | 强制规则".sh 是首选入口" | 会话首选入口被锁定 |
| `.cursor/rules/*.mdc` | 三条规则文件全引用 `.sh` | 规则加载阶段固化决策 |
| `settings.local.json` | 仅允许 `.sh` 权限 | `.bat` 脚本无执行权限 |

完整分析见：`app-medication/WINDOWS-SCRIPT-CALL-ANALYSIS.md`

### 已修复项 ✅

1. **AGENTS.md**
   - 新增 `Platform Detection` 章节，定义平台检测规则
   - 修改 `Script Rules`：区分 Windows (.bat) 和 Unix (.sh)
   - 修改 `Preferred Debug Entry Points`：分平台展示命令

2. **`.cursor/rules/10-workspace-structure.mdc`**
   - 新增 `Platform Detection` 章节
   - 修改 `Root Rules` / `App Rules`：同时提及 `.sh` 和 `.bat`

3. **`.cursor/rules/30-scripts-and-debug.mdc`**
   - 新增 `Platform Detection` 章节
   - 修改 `Primary Execution Path`：平台自适应
   - 修改 `Preferred Debug Entry Points`：分 Windows / macOS/Linux

4. **`.cursor/rules/50-app-initialization.mdc`**
   - 修改 `Required App Skeleton`：增加 `.bat` 脚本要求
   - 修改 `Verification Minimum`：平台自适应验证命令

5. **CLAUDE.md**
   - 修改 Goals：提及两个平台脚本
   - 新增 `Quick Start (Windows)` 章节

6. **`app-medication/.claude/settings.local.json`**
   - 增加 `.bat` 脚本执行权限

### 验证结果（平台检测规则修复）

```cmd
cmd.exe //c "call D:\\app-harmony-os\\app-medication\\dev-start.bat"

[INFO]  "Checking DevEco tools..."
[INFO]  "Checking for connected HarmonyOS device..."
[OK]    "HarmonyOS simulator/device already connected"
[INFO]  "Building app-medication (debug)..."
```

- ✅ `dev-start.bat` 正确调用
- ✅ Windows 路径正确（无 `/Contents/` 目录）
- ✅ DevEco 工具链检测通过
- ✅ 设备连接检测通过
- ⚠️ hvigor 构建报错：根目录缺少 `build-profile.json5`（项目结构问题，非本次修复范围）

### 修改文件清单

| 文件 | 变更说明 |
|------|---------|
| `AGENTS.md` | 新增 Platform Detection + 修改 Script Rules + 分平台 Debug Entry |
| `.cursor/rules/10-workspace-structure.mdc` | 新增 Platform Detection + 同时提及 .bat/.sh |
| `.cursor/rules/30-scripts-and-debug.mdc` | 新增 Platform Detection + 分平台命令示例 |
| `.cursor/rules/50-app-initialization.mdc` | App Skeleton 增加 .bat + Verification 分平台 |
| `CLAUDE.md` | Goals 修改 + 新增 Windows Quick Start |
| `app-medication/.claude/settings.local.json` | 增加 .bat 脚本执行权限 |
| `app-medication/WINDOWS-SCRIPT-CALL-ANALYSIS.md` | 问题分析文档（新建） |

### Dev 环境启动验证（补全 build-profile.json5 后）

首次运行因缺少根级 `build-profile.json5` 构建失败，从 `app-hello` 参照补建后重新执行：

**执行命令：**

```cmd
cmd.exe //c "call D:\\app-harmony-os\\app-medication\\dev-start.bat"
```

**执行结果：**

```
[INFO]  "Checking DevEco tools..."
[INFO]  "Checking for connected HarmonyOS device..."
[OK]    "HarmonyOS simulator/device already connected"
[INFO]  "Building app-medication (debug)..."
> hvigor Finished :entry:default@CompileArkTS... after 36 s 352 ms
> hvigor Finished ::PackageApp... after 780 ms
> hvigor BUILD SUCCESSFUL in 1 min 20 s 663 ms
[INFO]  "Checking device connection..."
[OK]    "Device connected"
[INFO]  "Installing: ...\entry-default.hap"
[Info]App install path:...\entry-default.hap msg:install bundle successfully.
[INFO]  "Launching app-medication..."
start ability successfully.
[OK]    "Dev start completed for app-medication"
```

**验证结论：**

| 阶段 | 结果 |
|------|------|
| DevEco 工具链检测 | ✅ 通过 |
| 设备连接检测 | ✅ 通过（模拟器已连接） |
| 构建 (assembleApp) | ✅ BUILD SUCCESSFUL (1m20s) |
| 安装 (hdc install) | ✅ install bundle successfully |
| 启动 (aa start) | ✅ start ability successfully |

**附带修复项：**

| 文件 | 说明 |
|------|------|
| `app-medication/build-profile.json5` | 新建，参照 `app-hello` 模板，解决 hvigor 构建找不到项目配置的问题 |

**ArkTS 编译警告（不影响运行）：**

- `ReminderStore.ets`：多处理发可能抛异常的函数调用
- `MedicineLoader.ets`：`getRawFile` 已标记 deprecated
- `SoundEffectPlayer.ets`：多处理发可能抛异常的函数调用
- `StrongReminderService.ets`：`backgroundTaskManager` 部分设备不支持、`vibrate`/`stop` 已 deprecated
- `Index.ets`：`requestEnableNotification`、`PhotoViewPicker` 等已 deprecated


---

> **注**：2026-04-13 拍照识别药品名称（OCR + 药品库匹配）相关内容已移至 `REQ0.3.md`。
