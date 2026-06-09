# TimeOut for macOS

[English README](README.md)

TimeOut 是一个基于 SwiftUI + AppKit 打造的精致 macOS 菜单栏休息提醒应用，灵感来自经典的 Time Out。它通过微休息、常规休息、智能规则、多屏遮罩、通知、统计和中英文界面，帮助你减少眼疲劳、久坐和长时间工作的疲惫感。

## 功能亮点

- **微休息 / 常规休息**：分别配置短而频繁的微休息，以及更长的常规休息。
- **菜单栏倒计时**：可选择在菜单栏图标旁显示实时倒计时。
- **多屏遮罩**：在所有连接的显示器上显示休息遮罩，并带有淡入淡出动画。
- **休息主题**：支持计时器、呼吸、护眼、拉伸、自定义文字等主题。
- **休息预告**：休息开始前显示短暂准备阶段，可一键立即开始休息。
- **推迟 / 跳过**：支持推迟 1 / 5 / 15 分钟，也可按需跳过。
- **智能规则**：全屏应用、排除应用、计划时间外等场景可自动推迟或跳过。
- **计划时间**：可设置启用时段、仅工作日，并支持跨午夜时间段。
- **自然休息识别**：检测空闲、睡眠、锁屏等自然离开场景并重置计时。
- **通知与声音**：可配置休息前、开始、结束、规则推迟时的通知和提示音。
- **今日统计**：统计已完成、跳过、推迟、规则推迟、自然休息次数。
- **限制机制**：可限制每次休息的推迟次数和每日跳过次数，让休息更有意义。
- **中英文界面**：在“设置 → 通用 → 语言”中切换；首次启动会自动识别系统语言。
- **登录时启动**：可选择登录系统时自动启动 TimeOut。

## 构建与打包

**环境要求：** macOS 14.0+（Sonoma），Swift 5.9+

### 快速开始

```bash
# 直接构建并运行
make run

# 或使用 Swift Package Manager
swift run
```

### 创建 .app 应用包

```bash
# 按当前架构打包应用（生成 TimeOut-arm64.app 或 TimeOut-x86_64.app）
make package

# 安装到 /Applications/TimeOut.app（不带架构后缀）
make install

# 指定架构打包
make package ARCH=arm64
make package ARCH=x86_64
```

### 常用命令

```bash
make help       # 查看所有可用命令
make build      # 构建 release 二进制
make package    # 创建 .app 应用包
make install    # 安装到 /Applications/TimeOut.app
make run        # 构建并运行
make test       # 运行测试
make clean      # 清理构建产物
```

## 设置说明

打开菜单栏图标并选择 **设置…**。

- **休息**：启用 / 禁用微休息和常规休息，配置间隔、持续时间、空闲重置阈值和主题。
- **规则**：配置启用计划、全屏行为和排除应用。
- **提醒**：配置通知、声音、跳过 / 推迟限制。
- **统计**：查看今天的休息活动统计。
- **通用**：配置菜单栏倒计时、登录时启动和语言。

## 开发

可以用 Xcode 打开项目目录后运行，也可以使用 `swift run` 快速测试。

## 发布

### 下载最新版本

访问 [Releases 页面](https://github.com/cuckoohello/TimeOut/releases) 下载最新版本。

### 创建新版本发布

推送版本标签后，GitHub Actions 会自动构建并发布：

```bash
# 1. 可选：更新 Makefile 中的版本号
# 2. 提交改动
git add .
git commit -m "chore: bump version to 1.0.0"

# 3. 创建并推送版本标签
git tag v1.0.0
git push origin v1.0.0

# 4. GitHub Actions 会自动：
#    - 构建应用
#    - 创建 ZIP 压缩包
#    - 发布到 GitHub Releases
```

### 手动构建发布包

```bash
make release    # 创建 .app 应用包和 .zip 压缩包
make zip        # 仅基于现有 .app 创建 .zip 压缩包
```
