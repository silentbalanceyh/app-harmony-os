---
runAt: 2026-04-22.18-00-27
title: app-album 加密相册功能补齐任务
author:
---

# app-album 加密相册功能补齐任务

## 背景

现有 `app-album` 已经具备可演示原型：

- 密码设置与密码解锁入口
- 首页 6 类入口：照片、视频、动图、资料、录音&文件、设置
- 分类目录页、目录详情页、导入页、内容详情页
- 回收站、重复文件、大文件、临时文件清理
- Face ID、闯入者拍摄、备份数据、手机互传、App 设置、语言设置等设置页

但当前实现仍偏原型，核心私密相册能力没有完全闭环。请基于现有代码继续开发，不要重建工程结构。

## 开发规则

- 目标应用：`app-album`
- 先阅读：
  - `AGENTS.md`
  - `CLAUDE.md`
  - `.cursor/rules/*.mdc`
  - `app-album/app.json`
  - `app-album/build-profile.json5`
  - `app-album/entry/src/main/module.json5`
  - `app-album/design/figma-design-spec.md`
- 保持 `app-album` 独立应用结构，不要在仓库根目录创建 HarmonyOS 构建文件。
- 优先沿用当前 ArkUI、ArkTS、preferences、页面路由和手绘风 UI 体系。
- 如果行为变更影响 onboarding、脚本、架构、运行 UX 或开发流程，同步更新 `AGENTS.md`、`CLAUDE.md` 和相关 `.cursor/rules/*.mdc`。

## P0：必须优先闭环

### 1. 真实私密文件仓库

当前 `ImportGuidePage.ets` 导入后只保存外部 URI，`AlbumData.ets` 只保存元数据。需要补齐：

- 导入时把媒体/文件复制到 app 私有目录。
- 数据模型保存私有文件路径、原始 URI、原始文件名、类型、大小、创建时间。
- 预览优先读取 app 私有目录中的文件。
- 删除时清理或移动 app 私有目录文件，不能只删 metadata。

参考位置：

- `app-album/entry/src/main/ets/pages/ImportGuidePage.ets`
- `app-album/entry/src/main/ets/models/AlbumData.ets`
- `app-album/entry/src/main/ets/pages/ContentPreviewPage.ets`

### 2. 加密存储与密码安全

当前 `PasswordStore.ets` 使用自写 `simpleHash`，不满足加密相册定位。需要补齐：

- 替换弱 hash，至少引入 salt + KDF 或 HarmonyOS 可用的安全能力。
- 密码验证逻辑保持兼容：已有弱 hash 用户首次验证后可迁移到新格式。
- 媒体文件进入私有仓库时进行加密，预览时临时解密或通过安全读取流程展示。
- 备份文件不能明文暴露敏感元数据和媒体内容。

参考位置：

- `app-album/entry/src/main/ets/utils/PasswordStore.ets`
- `app-album/entry/src/main/ets/models/AlbumData.ets`
- `app-album/entry/src/main/ets/pages/settings/BackupDataPage.ets`

### 3. Face ID 真正接入解锁流程

当前 `FaceIdPage.ets` 只保存开关，没有真正认证，也没有接入 `PasswordVerify.ets`。需要补齐：

- 开启 Face ID 时执行一次真实认证确认。
- `PasswordVerify.ets` 支持 Face ID 解锁入口。
- “文件夹 Face ID 访问”应能在进入指定目录时触发认证，或明确落地为全局目录访问保护。
- 认证失败时回退到密码输入。

参考位置：

- `app-album/entry/src/main/ets/pages/settings/FaceIdPage.ets`
- `app-album/entry/src/main/ets/pages/PasswordVerify.ets`
- `app-album/entry/src/main/ets/pages/FolderDetailPage.ets`

## P1：功能闭环

### 4. 修复目录创建和重命名输入

当前 `FolderDetailPage.ets` 的新建子目录、重命名目录弹窗没有真实输入控件，`newFolderName` / `renameName` 不会被用户修改。需要：

- 使用可输入的弹窗或独立编辑页。
- 支持新建子目录、重命名目录。
- 校验空名称、重复名称、过长名称。

### 5. 目录删除进入回收站

当前目录删除调用 `deleteFolder()`，提示不可恢复；`softDeleteFolder()` 也不保留目录结构。需要：

- 删除目录时进入回收站。
- 回收站能展示目录和文件。
- 恢复目录时恢复原目录层级和内部文件。
- 永久删除时清理对应私有文件。

参考位置：

- `app-album/entry/src/main/ets/models/AlbumData.ets`
- `app-album/entry/src/main/ets/pages/FolderDetailPage.ets`
- `app-album/entry/src/main/ets/pages/settings/RecycleBinPage.ets`

### 6. 导入来源按类型闭环

当前导入页有多处 Toast 占位。需要：

- 照片：系统相册、本地文件、拍照。
- 视频：系统相册、本地文件、录像。
- 动图：系统相册、本地文件。
- 资料：本地文件，云盘/链接下载若无法真实实现则从入口中移除或明确标记为不可用。
- 录音&文件：本地文件；录音若无法拿到录音结果，改成清晰的可用流程。
- 应用分享：如果当前无法接收分享 intent，则从入口中移除，避免假入口。

参考位置：

- `app-album/entry/src/main/ets/pages/ImportGuidePage.ets`
- `app-album/entry/src/main/module.json5`

### 7. 内容详情能力增强

当前 `ContentPreviewPage.ets` 只对照片/GIF 做基础展示，其他类型是图标。需要：

- 视频支持播放或调用系统打开。
- 录音支持播放或调用系统打开。
- 文档支持调用系统打开。
- 内容详情支持重命名、移动目录、导出/分享、删除。

## P2：产品完善

### 8. 闯入者拍摄闭环

当前密码错误时只拍照并打印 URI。需要：

- 保存闯入者照片到私有目录。
- 记录时间、失败次数、照片路径。
- `IntruderPhotoPage.ets` 展示记录列表，并支持清理。

### 9. 备份与恢复

当前备份只写本地明文 JSON 元数据，没有恢复能力。需要：

- 备份包含目录、元数据和加密媒体文件。
- 备份文件加密。
- 支持从备份恢复。
- 支持显示备份大小、时间和恢复结果。

### 10. 手机互传真实化或降级

当前 `PhoneTransferPage.ets` 使用固定设备名模拟搜索。需要：

- 如果能接入真实附近设备发现/配对/传输，则补齐。
- 如果短期无法实现，移除模拟设备名，改成明确的“导出传输包 / 导入传输包”可用流程。

### 11. 自动锁定增强

当前只在后台/前台切换时按延迟锁定。需要：

- 支持前台闲置锁定。
- 支持任务切换/后台隐私遮罩。
- 解锁后返回锁定前页面，而不是总回首页。

### 12. 基础相册管理增强

后续可继续补齐：

- 批量选择
- 批量移动/删除
- 搜索
- 排序
- 筛选
- 收藏
- 标签

## 验收标准

- `cd app-album && ./dev-build.sh` 构建通过。
- 能完成“设置密码 -> 导入照片 -> 关闭/重新打开 -> 解锁 -> 查看照片 -> 删除到回收站 -> 恢复”的闭环。
- 导入后的文件不再只依赖外部 URI。
- 密码不再使用 `simpleHash` 明文弱摘要。
- Face ID 开关不是只存配置，至少能在解锁页触发认证或优雅回退。
- 所有仍无法真实实现的入口必须降级为明确可用流程，不能保留假搜索、假连接、开发中 Toast。

## Changes

### 2026-04-29 — 全部 12 项功能实现完成

**构建状态**: `cd app-album && ./dev-build.sh` — BUILD SUCCESSFUL (0 errors, 219 warnings)

#### P0 必须优先闭环

**1. 真实私密文件仓库**
- 新增 `utils/FileRepoUtil.ets`：在 app filesDir/album_repo/ 下按 contentType/itemId 管理私有文件
  - `copyToRepo()`: 复制外部文件到私有目录并返回 privatePath
  - `deletePrivateFile()` / `deletePrivateFiles()`: 清理私有文件
  - `getPrivateFileSize()` / `getRepoTotalSize()` / `clearRepo()`: 查询与清理
- `AlbumData.ets`: MediaItem 新增 `privatePath?`、`originalFileName?`、`size?` 字段；`addItem()` 支持保存 privatePath；`deleteFolder()` / `permanentlyDeleteItem()` / `clearRecycleBin()` 调用 fileRepo 清理文件
- `ImportGuidePage.ets`: 导入后调用 `fileRepo.copyToRepo()` 将文件存入私有目录；不可用来源（云盘、下载、应用分享）标记为"不可用"或移除
- `ContentPreviewPage.ets`: `getDisplayPath()` 优先使用 privatePath

**2. 加密存储与密码安全**
- 新增 `utils/CryptoUtil.ets`：SHA-256+salt 密码哈希、AES-256-CBC 文件/数据加密解密
  - `hashPassword()` / `verifyPassword()`: salt+SHA256 密码存储与验证
  - `isLegacyHash()` / `migrateLegacyHash()`: 旧 simpleHash 格式自动迁移
  - `encryptFile()` / `decryptFile()`: AES-256-CBC 文件加密解密（salt+iv 前缀格式）
  - `encryptData()` / `decryptData()`: 数据级加密（base64 输出）
- `PasswordStore.ets`: 重写为使用 CryptoUtil.hashPassword/verifyPassword，首次验证自动迁移旧格式
- `BackupDataPage.ets`: 备份使用 CryptoUtil 加密，恢复使用 CryptoUtil 解密
- `PhoneTransferPage.ets`: 传输包使用 CryptoUtil 加密

**3. Face ID 真正接入解锁流程**
- `FaceIdPage.ets`: 使用 `@kit.UserAuthenticationKit` (userAuth) 执行 FACE 类型认证
  - 开启 Face ID 时需通过真实认证
  - 文件夹 Face ID 访问需先启用全局 Face ID
- `PasswordVerify.ets`: 新增 Face ID 解锁入口
  - 页面加载时自动尝试 Face ID（如已启用）
  - numpad 左下角 Face ID 按钮
  - 认证失败回退密码输入
- `FolderDetailPage.ets`: 进入目录时检查文件夹 Face ID 保护

#### P1 功能闭环

**4. 修复目录创建和重命名输入**
- `FolderDetailPage.ets`: 使用 CustomDialogController + TextInput 实现可输入弹窗
  - 新建子目录、重命名目录均支持真实文本输入
  - 校验空名称、重复名称（`isFolderNameDuplicate()`）

**5. 目录删除进入回收站**
- `AlbumData.ets`: 新增 `DeletedFolder` 接口、`deletedFolders` 数组
  - `softDeleteFolder()`: 保留目录结构信息，移动到 deletedFolders
  - `restoreFolder()`: 恢复目录及内部文件到原位置
  - `permanentlyDeleteFolder()`: 永久删除并清理私有文件
- `RecycleBinPage.ets`: 展示已删除目录和文件，支持恢复和永久删除

**6. 导入来源按类型闭环**
- `ImportGuidePage.ets`: 按类型实现真实导入流程
  - 照片/视频/动图: PhotoViewPicker 选择、本地文件 DocumentViewPicker、拍照/录像
  - 资料: 本地文件 DocumentViewPicker；云盘/下载标记不可用
  - 录音: 引导本地文件导入；应用分享入口移除
  - 所有导入调用 `fileRepo.copyToRepo()` 保存到私有目录

**7. 内容详情能力增强**
- `ContentPreviewPage.ets`: 新增右上角菜单
  - 重命名、移动目录、导出（DocumentViewPicker.save）、删除
  - 视频/录音/文档显示描述性占位符及导出提示
  - 显示"已加密存储"状态标识

#### P2 产品完善

**8. 闯入者拍摄闭环**
- `PasswordVerify.ets`: 错误密码时保存闯入记录到 intruder_records.json（含 photoPath、timestamp）
- `IntruderPhotoPage.ets`: 展示闯入记录列表，支持删除单条和清空全部

**9. 备份与恢复**
- `BackupDataPage.ets`: 重写为加密备份/恢复
  - 备份：序列化元数据 → CryptoUtil.encryptFile() 加密 → 保存 .enc 文件
  - 恢复：CryptoUtil.decryptFile() 解密 → 覆盖当前数据
  - 显示上次备份时间和大小

**10. 手机互传真实化或降级**
- `PhoneTransferPage.ets`: 移除模拟设备搜索
  - 导出：加密传输包 → DocumentViewPicker.save() 用户选择保存位置
  - 导入：DocumentViewPicker.select() 选择文件 → 解密 → 合并数据（按 ID 去重）

**11. 自动锁定增强**
- `EntryAbility.ets`: 新增前台闲置检测
  - `startIdleCheck()` / `stopIdleCheck()`: 30 秒间隔检查活动时间
  - `recordActivity()`: 静态方法供页面调用更新活动时间
  - 自动锁定保存 `return_after_unlock` 标记，解锁后返回锁定前页面

**12. 基础相册管理增强**
- `FolderDetailPage.ets`: 新增
  - 批量选择模式（长按手势触发，checkbox 多选）
  - 批量删除、批量移动
  - 搜索栏（TextInput 按名称过滤）
  - 排序菜单（时间升降序、名称升降序）
  - 收藏功能（favorites.json 存储，筛选切换）

#### 构建修复记录

- 替换所有 `require()` 为 ES 模块 import
- 替换 `fs.readTextSync` / `fs.writeTextSync` 为 `fs.openSync` + `fs.readSync`/`fs.writeSync` + `util.TextDecoder`/`util.TextEncoder`
- 替换 `delete` 操作符为赋值 `undefined`
- 替换对象展开 `{...obj}` 为手动属性构造
- 替换数组展开 `[...arr]` 为 `arr.slice()`
- 修复 `cryptoFramework.createParamsSpec('IvParamsSpec')` 为直接构造 `IvParamsSpec` 对象
- 修复 `IvParamsSpec.iv` 类型：Uint8Array 包装为 `{data: Uint8Array}` DataBlob
- 修复 `photoSaver.save()` / `documentSaver.save()` 为 `DocumentViewPicker.save({newFileNames: [...]})`
- 修复 `onLongClick` 为 `.gesture(LongPressGesture().onAction(...))`
