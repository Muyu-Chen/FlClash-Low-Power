# 编译工具卸载指南

## 当前工具链

| 组件 | 版本 | 路径 |
|------|------|------|
| Flutter SDK | 3.47.7（Dart 3.13.5） | `/opt/homebrew/share/flutter` |
| Go | 1.27.2 | `/opt/homebrew/opt/go` |
| Rust | 1.99.1 | `~/.rustup/toolchains/1.99.1-aarch64-apple-darwin` |
| rustup | 1.29.1 | `/opt/homebrew/opt/rustup` |

Rust 由 rustup 管理；旧 Flutter、Go 和 Rust SDK 及重复的 Homebrew Rust 已删除。

## 完全卸载

按顺序执行：

### 1. 卸载 Flutter SDK

```bash
brew uninstall --cask flutter
```

### 2. 卸载 Go

```bash
brew uninstall go
```

### 3. 卸载 rustup 和 Rust 工具链

```bash
rustup toolchain uninstall 1.99.1
brew uninstall rustup
```

### 4. 卸载 CocoaPods（及不再需要的依赖）

```bash
brew uninstall cocoapods
# 如果 Ruby 不再被其他软件需要：
brew autoremove
```

### 5. 清理 Homebrew 原生 Rust（如果之前有）

```bash
brew uninstall rust
```

### 6. 清理 Flutter/Dart 缓存

```bash
rm -rf ~/.pub-cache
rm -rf ~/.dart_tool
rm -rf ~/.flutter
```

### 7. 清理 Go 模块缓存

```bash
rm -rf ~/go
```

### 8. 清理 FlClash 项目本地构建产物

```bash
# 在项目目录中执行
rm -rf build/
rm -rf .dart_tool/
rm -rf macos/Pods/
rm -rf macos/Flutter/ephemeral/
rm -rf core/Clash.Meta
```

> 第 8 步会删除 Core 子模块检出目录，执行前确认其中没有需要保留的本地修改。

---

## 只清理构建缓存（保留工具链）

```bash
# 在项目目录中执行
rm -rf build/
rm -rf .dart_tool/
rm -rf macos/Pods/
rm -rf macos/Flutter/ephemeral/
flutter clean
```

---

## 注意

- 卸载编译工具不会影响已编译出的 `.app` 文件
- Xcode 本身未计入（约 12+ GB，之前已有）
- 本机只保留 rustup 管理的 Rust 1.99.1，与项目构建钩子的版本一致。
