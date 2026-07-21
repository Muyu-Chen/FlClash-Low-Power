# 编译工具卸载指南

## 本次安装新增空间占用

| 组件 | 版本 | 路径 | 大小 |
|------|------|------|------|
| Flutter SDK | 3.44.6 | `/opt/homebrew/share/flutter` | ~3.8 GB |
| Go | 1.26.5 | `/opt/homebrew/Cellar/go` | ~258 MB |
| Rust (rustup) | 1.97.1 | `~/.rustup` + `~/.cargo` | ~1.5 GB |
| CocoaPods | 1.17.0 | `/opt/homebrew/Cellar/cocoapods` | ~24 MB |
| Ruby (CocoaPods 依赖) | 4.0.6 | `/opt/homebrew/Cellar/ruby` | ~59 MB |
| Core 子模块 (Clash.Meta) | e6eb546 | `core/Clash.Meta` | ~6 MB |
| Dart/Flutter pub 缓存 | — | `~/.pub-cache` | ~1–1.5 GB |
| Go 模块缓存 | — | `~/go` | ~200 MB |
| Flutter 构建缓存 | — | `build/` + Xcode DerivedData | ~3–5 GB |
| **合计** | | | **约 10–13 GB** |

---

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
rustup self uninstall -y
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

> 第 8 步只清除构建产物和子模块缓存，不会删除源代码和你的修改。

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
- 如果 Homebrew 之前已有 `rust`，`rustup` 安装后两者共存（rustup 在 `/opt/homebrew/opt/rustup/bin`，brew rust 在 `/opt/homebrew/bin`）
