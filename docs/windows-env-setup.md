# HarmonyOS Windows 环境配置指南

## 环境要求

- Windows 11 或 Windows 10
- DevEco Studio 已安装
- HarmonyOS SDK 已通过 DevEco Studio 下载

## 默认路径配置

批处理脚本使用以下默认路径：

```
DEVECO_STUDIO_PATH=C:\Program Files\Huawei\DevEco Studio
DEVECO_SDK_ROOT=%DEVECO_STUDIO_PATH%\sdk\default
DEVECO_HDC=%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe
DEVECO_HVIGORW=%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.bat
DEVECO_EMULATOR=%DEVECO_STUDIO_PATH%\tools\emulator\Emulator.exe
EMULATOR_INSTANCE_PATH=%USERPROFILE%\.Huawei\Emulator\deployed
EMULATOR_IMAGE_ROOT=%USERPROFILE%\.Huawei\Sdk
```

## 设置环境变量

如果 DevEco Studio 安装在其他位置，需要设置环境变量：

### 方法一：系统环境变量（推荐）

1. 打开"系统属性" → "高级" → "环境变量"
2. 在"系统变量"中添加：

```
DEVECO_STUDIO_PATH=你的DevEco安装路径
```

例如：
```
DEVECO_STUDIO_PATH=D:\DevEco\DevEco Studio
```

### 方法二：临时环境变量（当前命令行窗口）

```cmd
set DEVECO_STUDIO_PATH=D:\DevEco\DevEco Studio
```

### 方法三：用户环境变量（持久）

在 PowerShell 中执行：

```powershell
[Environment]::SetEnvironmentVariable("DEVECO_STUDIO_PATH", "D:\DevEco\DevEco Studio", "User")
```

## 可选环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `AUTO_START_EMULATOR` | 是否自动启动模拟器 | `true` |
| `EMULATOR_NAME` | 指定模拟器实例名称 | 自动选择第一个 |
| `EMULATOR_HDC_PORT` | 模拟器 HDC 端口 | 自动分配 |
| `LAUNCH_DEPENDENCIES` | 是否启动依赖应用 | `false` |
| `device` (在app.json中) | 指定目标设备ID | 空（使用默认） |

## 使用批处理脚本

### 根目录脚本

```cmd
start-simulator.bat    # 启动模拟器或检查连接
```

### 应用目录脚本（每个 app-* 目录）

```cmd
dev-build.bat          # 构建当前应用（debug模式）
dev-start.bat          # 开发启动（构建+部署+启动）
dev-stop.bat           # 停止 hvigor 进程
run-start.bat          # 发布启动（release模式构建）
```

### 快速开发流程

```cmd
# 1. 启动模拟器
start-simulator.bat

# 2. 进入应用目录并启动
cd app-center
dev-start.bat

# 3. 查看日志（需要 hdc 命令）
hdc shell hilog -x
```

## 常见问题

### 1. 路径不存在

检查 DevEco Studio 安装路径是否正确。确认以下文件/目录存在：

- `%DEVECO_STUDIO_PATH%\sdk\default\openharmony\toolchains\hdc.exe`
- `%DEVECO_STUDIO_PATH%\tools\hvigor\bin\hvigorw.bat`
- `%DEVECO_STUDIO_PATH%\tools\emulator\Emulator.exe`

### 2. hdc 命令无法连接

1. 确保 HarmonyOS 模拟器正在运行
2. 在 DevEco Device Manager 中检查设备状态
3. 运行 `hdc list targets` 查看已连接设备

### 3. hvigor 构建失败

1. 检查 SDK 是否完整下载
2. 确认 `%DEVECO_SDK_ROOT%\sdk-pkg.json` 文件存在
3. 尝试在 DevEco Studio 中手动构建一次

### 4. 符号链接创建失败

`mklink /j` 命令在创建 junction 时可能需要管理员权限。如果失败：

1. 以管理员身份运行命令提示符
2. 或者手动设置环境变量：

```cmd
set DEVECO_SDK_HOME=%APP_ROOT%\.deveco-sdk-shim
set OHOS_BASE_SDK_HOME=%DEVECO_SDK_HOME%\<version_path>\openharmony
```

## 与原 Shell 脚本的对应关系

| Shell 脚本 | 批处理脚本 |
|------------|------------|
| `start-simulator.sh` | `start-simulator.bat` |
| `scripts/common.sh` | `scripts\common.bat` |
| `dev-build.sh` | `dev-build.bat` |
| `dev-start.sh` | `dev-start.bat` |
| `dev-stop.sh` | `dev-stop.bat` |
| `run-start.sh` | `run-start.bat` |

## PowerShell 替代方案

如果偏好 PowerShell，也可以使用 PowerShell 脚本：

```powershell
# 运行批处理脚本
& ".\start-simulator.bat"

# 或者设置环境变量后直接调用 DevEco 工具
$env:DEVECO_STUDIO_PATH = "C:\Program Files\Huawei\DevEco Studio"
& "$env:DEVECO_STUDIO_PATH\sdk\default\openharmony\toolchains\hdc.exe" list targets
```