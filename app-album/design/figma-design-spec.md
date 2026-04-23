# 私密相册 Figma 设计说明：现有功能 Excalidraw 手绘风版

## 1. 修订原则

上一版偏产品愿景，包含了一些当前工程还没有实现的能力。此版本改为严格贴合现有 `app-album` 功能。

本版不表现：

- 内容搜索
- 内容筛选
- 安全评分
- 异常提醒
- 自动扫描
- 当前代码没有的统计面板

说明：`手机互传` 页面里的“搜索附近设备”是当前代码已有功能，应保留。

本版重点表现：

- 密码解锁
- 首页 6 个功能入口
- 照片目录页
- 视频目录页
- 动图目录页
- 资料目录页
- 录音&文件目录页
- 目录详情页
- 导入照片页
- 设置分组页
- 内容详情
- 回收站
- 重复文件 / 大文件 / 临时文件清理
- Face ID / 闯入者拍摄 / 密码修改
- 备份数据 / 手机互传 / App 设置 / 语言设置

示例内容规则：

- 不假设真实用户目录名
- 不预设“家庭照片”“旅行相册”“证件资料”这类业务语义
- 统一使用 `主目录`、`目录 01`、`子目录 01` 这类占位方式

## 2. 当前代码映射

设计稿与代码页面对应：

- `01-unlock`: `PasswordVerify.ets`
- `02-main`: `MainPage.ets`
- `03-photos`: `PhotosPage.ets`
- `04-videos`: `VideosPage.ets`
- `05-gifs`: `GifsPage.ets`
- `06-docs`: `DocsPage.ets`
- `07-records`: `RecordsPage.ets`
- `08-folder-detail`: `FolderDetailPage.ets`
- `09-import`: `ImportGuidePage.ets`
- `10-settings`: `SettingsPage.ets`
- `11-preview`: `ContentPreviewPage.ets`
- `12-recycle-bin`: `RecycleBinPage.ets`
- `13-duplicate-files`: `DuplicateFilesPage.ets`
- `14-large-files`: `LargeFilesPage.ets`
- `15-clean-temp`: `CleanTempPage.ets`
- `16-face-id`: `FaceIdPage.ets`
- `17-intruder-photo`: `IntruderPhotoPage.ets`
- `18-password-security`: `PasswordSecurityPage.ets`
- `19-backup-data`: `BackupDataPage.ets`
- `20-phone-transfer`: `PhoneTransferPage.ets`
- `21-app-settings`: `AppSettingsPage.ets`
- `22-language-settings`: `LanguageSettingsPage.ets`

## 3. 视觉方向

关键词：

- 手绘
- 轻松
- 草图感
- 安全但不压抑
- 手机端一眼可懂

视觉处理：

- 淡纸色背景
- 双线手绘描边
- 轻阴影
- 低饱和分类色
- 草图式卡片与按钮
- 保留轻量吉祥物用于缓和安全产品的严肃感

这套风格更接近 Excalidraw 的手绘草图语言，适合在评审阶段快速表达产品结构，又不会脱离当前已完成的功能面。

## 4. 页面说明

### 4.1 密码解锁

对应当前 `PasswordVerify.ets`。

保留现有功能：

- 标题“加密相册”
- 提示“请输入密码以解锁”
- 6 位密码圆点
- 数字键盘
- 删除键
- 闯入者拍摄提示

不表现未实现能力：

- 不显示“忘记密码”
- 不显示安全事件
- 不显示设备状态

### 4.2 首页宫格

对应当前 `MainPage.ets`。

保留 6 个入口：

- 照片
- 视频
- 动图
- 资料
- 录音&文件
- 设置

页面只强化视觉，不新增信息面板。顶部卡片只说明“密码保护的安全空间”，符合当前产品定位。

### 4.3 分类目录

对应当前五个分类页：

- `PhotosPage.ets`
- `VideosPage.ets`
- `GifsPage.ets`
- `DocsPage.ets`
- `RecordsPage.ets`

保留现有操作：

- 返回
- 右上角菜单
- 新建目录
- 导入照片 / 导入视频 / 导入动图 / 导入资料 / 导入文件
- 目录列表
- 空状态提示

注意：

- `新建目录` 和各类 `导入...` 都属于右上角菜单动作
- 不应直接作为主界面常驻按钮露出
- 设计稿应通过菜单展开态来表达，而不是页面主操作区按钮

不加入搜索、筛选、排序等当前页面没有的入口。

### 4.4 目录详情

对应当前 `FolderDetailPage.ets`。

保留现有操作：

- 返回
- 右上角菜单
- 新建子目录
- 导入照片
- 重命名目录
- 删除目录
- 子目录区域
- 内容网格

注意：

- 上述四个目录操作都是菜单项
- 设计稿应体现“点击右上角 ⋮ 后出现菜单”的关系

### 4.5 导入照片

对应当前 `ImportGuidePage.ets` 在 `photo` 类型下的来源：

- 系统相册
- 本地文件
- 拍照
- 应用分享

页面底部说明视频、动图、资料、录音&文件沿用同一版式，但只替换当前代码里已有的来源文案。

### 4.6 设置

对应当前 `SettingsPage.ets`。

严格保留当前四组：

- 文件管理
- 数据安全
- 密码相关
- 配置

每组里的条目也按当前代码列出。

### 4.7 内容详情

对应当前 `ContentPreviewPage.ets`。

保留现有信息结构：

- 预览区域
- 删除入口
- 名称
- 类型
- 大小
- 创建时间
- 文件路径

### 4.8 回收站

对应当前 `RecycleBinPage.ets`。

保留现有逻辑表达：

- 列表展示已删除内容
- 恢复
- 永久删除
- 清空回收站
- 30 天自动清理说明

### 4.9 文件管理扩展页

逐页对应：

- `DuplicateFilesPage.ets`
- `LargeFilesPage.ets`
- `CleanTempPage.ets`

### 4.10 安全相关页

逐页对应：

- `FaceIdPage.ets`
- `IntruderPhotoPage.ets`
- `PasswordSecurityPage.ets`

### 4.11 配置相关页

逐页对应：

- `BackupDataPage.ets`
- `PhoneTransferPage.ets`
- `AppSettingsPage.ets`
- `LanguageSettingsPage.ets`

## 5. Figma 建议结构

建议新建 Figma 文件：

- `Private Album Existing Feature Cartoon`

页面结构：

- `00 Cover`
- `01 Foundations`
- `02 Components`
- `03 Screens`
- `04 Flow Notes`

把 `svg/` 文件直接拖入 `03 Screens`，再拆解为组件。当前这套稿已收敛为“真实页面一一对应”的全集。

## 6. 设计 Token

颜色：

- Background: `#F8F6F0`
- Paper: `#FFFDF7`
- Ink: `#1F2328`
- Secondary Text: `#5F6368`
- Stroke: `#1F2328`
- Shadow: `#D7D0C4`
- Blue: `#A5D8FF`
- Lavender: `#D0BFFF`
- Mint: `#B2F2BB`
- Yellow: `#FFE066`
- Orange: `#FFD8A8`
- Pink: `#FFC9C9`
- Green: `#B2F2BB`
- Danger: `#FFA8A8`

字体：

- 首选 `Hannotate TC`
- 次选 `Hannotate SC`
- 回退 `PingFang TC` / `PingFang SC`

字号：

- 页面标题：`26-28`
- 卡片标题：`18-24`
- 正文：`14-16`
- 辅助说明：`13-14`

圆角：

- 大卡片：`14-16`
- 小卡片：`12-14`
- 胶囊按钮：`10`
- 数字键：`12`

描边：

- 主描边：`1.8-2.1`
- 次描边：`1.2-1.6`
- 推荐双线轻错位，模拟手绘感

阴影：

- 采用很轻的偏移阴影，不做厚重卡片压感。
- 当前稿里统一用浅灰棕阴影，偏移更小。

## 7. 后续落地建议

如果要把这套设计回推到 ArkUI，优先顺序建议：

1. 先替换首页宫格视觉。
2. 再统一返回按钮、菜单按钮、卡片、列表行。
3. 再调整密码页数字键盘和空状态。
4. 最后把设置页各二级页面也统一成同样卡通风格。

这次文档只负责设计稿，不修改 ArkUI 代码。
