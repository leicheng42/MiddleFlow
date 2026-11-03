# MiddleFlow for Windows

**中文** | [English](#english)

MiddleFlow 把鼠标中键变成一个 Windows 语音输入入口：单击开始/停止豆包输入法语音，双击在转写完成后发送回车；在 UU Remote 等画布应用中，会自动使用浮层收集文字并粘贴回原来的输入位置。

这是 Windows 10/11 的独立 WPF 版本，与 macOS 版本共享交互模型，但不修改 macOS Swift 工程。

## 功能

- 全局低层鼠标钩子拦截中键（button 2），启用映射时抑制原始中键事件。
- 单击按住右侧 Alt（`VK_RMENU` / AltGr），再次单击释放；豆包 Windows 输入法使用长按右侧 Alt。
- 双击停止语音；普通应用发送 Return，画布浮层在文字稳定后先粘贴再回车。
- UU Remote 等画布应用使用顶部浮层，支持实时 IME 组合文本、快速稳定检测、自动粘贴和剪贴板恢复。
- 普通应用使用直接模式，不弹浮层，豆包文字直接进入目标输入框。
- 托盘菜单：打开设置、语音测试、暂停/启用映射、退出。
- 设置页：概览、手势、语音、豆包输入法、应用、权限与状态、诊断、关于。
- 豆包 Windows 输入法检测：安装状态、键盘布局注册状态、当前输入法、版本和安装路径。
- 配置写入 `%LOCALAPPDATA%\MiddleFlow\settings.json`；诊断日志写入同一目录。
- 不采集音频，不保存转写正文，不上传内容。

## 快速使用

1. 从 [豆包输入法官网](https://shurufa.doubao.com/pc) 安装 Windows 版豆包输入法。
2. 在 Windows 设置中把豆包加入键盘列表，并切换到豆包输入法。
3. 在豆包输入法设置中确认语音快捷键是“右侧 Alt”长按。
4. 打开 MiddleFlow，进入“豆包输入法”页点击“重新检测”，确认状态为“已就绪”。
5. 打开“语音测试窗口”，把光标放进文本框，单击中键说话，再单击停止。
6. 在 UU Remote 或自定义画布应用中使用同样的中键手势；浮层会负责粘贴回原位置。

普通应用使用直接模式；画布应用匹配规则可以在“应用”页修改。默认规则包含 `uu.exe`、`uuclient.exe`、`uu_remote.exe`、`uu remote` 和 `uu远程`。

## 构建

要求：

- Windows 10/11
- .NET SDK 8.0
- PowerShell 7 或 Windows PowerShell 5.1

```powershell
cd windows
.\scripts\build.ps1
```

直接构建：

```powershell
dotnet build .\MiddleFlow.Windows.sln -c Release -p:EnableWindowsTargeting=true
```

运行两个 smoke test：

```powershell
dotnet run --project .\tests\MiddleFlow.Core.Tests\MiddleFlow.Core.Tests.csproj -c Release -p:EnableWindowsTargeting=true
dotnet run --project .\tests\MiddleFlow.Windows.Tests\MiddleFlow.Windows.Tests.csproj -c Release -p:EnableWindowsTargeting=true
```

## 发布

```powershell
.\scripts\publish.ps1 -Runtime win-x64 -Version 2.0.0
.\scripts\publish.ps1 -Runtime win-arm64 -Version 2.0.0
```

脚本使用 .NET 8 self-contained single-file 发布，输出到 `windows/dist/<runtime>`，并生成 `windows/dist/MiddleFlow-<version>-<runtime>.zip`。`-Version` 默认是 `2.0.0`，也接受带前导 `v` 的版本号；发布包不依赖目标机器预装 .NET。

## 配置与诊断

- 配置：`%LOCALAPPDATA%\MiddleFlow\settings.json`
- 日志：`%LOCALAPPDATA%\MiddleFlow\diagnostics.log`
- 日志只记录时间、事件、输入法状态、字符数量和进程名；不记录转写正文或音频。
- “诊断”页可以刷新、打开、复制和清空日志。

## 架构

```text
windows/
  src/MiddleFlow.Core/        # settings, gesture classifier, target policy, transcript stabilizer, Doubao detector
  src/MiddleFlow.Windows/     # WPF app, tray, mouse hook, SendInput, overlay, settings pages
  tests/MiddleFlow.Core.Tests # no-package smoke tests
  tests/MiddleFlow.Windows.Tests # cross-platform verification of Win32 INPUT layout
  scripts/                    # build, publish, icon generation
```

关键 Win32 细节：

- `INPUT` 使用显式布局联合体，包含 `MOUSEINPUT`、`KEYBDINPUT`、`HARDWAREINPUT`；x64 下应为 40 字节。
- 鼠标钩子只把 `WM_MBUTTONDOWN` 当作点击边沿；`WM_MBUTTONDBLCLK` 和 up 事件只抑制，不重复计数。
- 浮层粘贴前会激活原目标窗口，并在原始中键屏幕坐标发送一次左键聚焦，再发送 Ctrl+V。
- 文本稳定判定：稳定约 150ms 即完成；非空文本最长 1200ms 强制完成；空文本 2500ms 才报空结果。

## 已知限制

- Windows 版已完成源码级、XAML 编译、双架构发布和本地 smoke tests；GitHub Actions 的 Windows x64/ARM64 矩阵构建已通过。真实鼠标、豆包 IME、UU Remote 仍需在 Windows 10/11 机器上做硬件验收。
- 豆包输入法检测依赖 Windows 键盘布局、CTF 注册表和安装目录；不同豆包版本可能返回不同描述，检测失败时仍可通过测试窗口确认。
- 自包含包没有代码签名；公开分发前应配置 Authenticode 签名，减少 SmartScreen 提示。
- 画布应用匹配是进程名/窗口标题规则，不依赖屏幕 OCR 或远程控制协议。

## English

MiddleFlow turns the mouse middle button into a Windows voice-input bridge for the Doubao input method. A single click holds Right Alt to start listening and releases it on the next click; a double click stops listening and sends Return after transcription/paste. Canvas applications such as UU Remote use a focused voice composer that quickly stabilizes IME text, pastes it back to the original click position, and optionally restores the clipboard.

### Highlights

- Global low-level middle-button hook with suppression while mapping is enabled.
- Direct mode for ordinary apps and a polished topmost composer for canvas apps.
- Doubao installation, keyboard-layout, current-input-method, version, and path detection.
- Tray menu, pause/resume, settings pages, test window, diagnostics, and startup integration.
- No audio recording, transcript persistence, or uploads.
- .NET 8 WPF, no third-party NuGet packages, self-contained `win-x64` and `win-arm64` publish scripts.

### Build and test

```powershell
cd windows
.\scripts\build.ps1
.\scripts\publish.ps1 -Runtime win-x64 -Version 2.0.0
.\scripts\publish.ps1 -Runtime win-arm64 -Version 2.0.0
```

The GitHub Actions workflow builds both architectures and runs the core smoke tests plus the Win32 input-layout test. Real hardware validation on Windows 10/11 is still required before calling a build production-ready.

### Privacy

MiddleFlow does not record audio, log transcript text, inspect screen content, or send data to a server. Diagnostics contain only event names, status values, character counts, and process names.
