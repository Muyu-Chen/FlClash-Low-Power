# macOS 构建与发布

本文档为独立笔记，不影响上游 README 或 CI 配置，方便持续合并。

## 环境

- macOS 26 (Apple Silicon) + Xcode 26
- FVM 固定 Flutter 3.44.4，见 `.fvmrc`
- Go 1.21+（核心）、Rust（rustup 管理）、CocoaPods

### FVM 安装

```bash
curl -fsSL https://fvm.app/install.sh | bash
export PATH="$HOME/fvm/bin:$PATH"
fvm use 3.44.4 --skip-pub-get
```

- Flutter 3.44.4 FVM 缓存 ~1.2 GB
- 项目 `.fvm/` 仅含链接，已被 .gitignore 忽略

### FVM 卸载

```bash
fvm remove 3.44.4        # 只移除这一版 Flutter SDK
fvm destroy               # 移除全部 FVM 缓存的 SDK
curl -fsSL https://fvm.app/install.sh | bash -s -- --uninstall  # 卸载 FVM
```

### 其他工具

```bash
brew install go cocoapods rustup-init
rustup default stable
```

本机实测额外占用：

| 工具 | 路径 | 大小 |
|------|------|------|
| Flutter SDK 3.44.6 | `/opt/homebrew/share/flutter` | ~3.8 GB |
| Go 1.26 | `/opt/homebrew/Cellar/go` | ~258 MB |
| Rust (rustup) | `~/.rustup` + `~/.cargo` | ~1.6 GB |
| CocoaPods | `/opt/homebrew/Cellar/cocoapods` | ~24 MB |
| pub 缓存 | `~/.pub-cache` | ~1 GB |
| Go 模块缓存 | `~/go` | ~400 MB |
| **合计** | | **~7 GB** |

详细卸载见 `low-power-doc/uninstall-build-tools.md`。

## 构建

### 快速构建 (Apple Silicon only)

```bash
make macos-arm64
```

等价于 `bash macos/packaging/release_arm64.sh`。

### 发布脚本 `macos/packaging/release_arm64.sh`

构建 Apple Silicon-only `.app`，移除 Intel 切片，本地 ad-hoc 签名，打包为 zip。

```bash
# 本地 ad-hoc 签名（无 PRE 标志）
bash macos/packaging/release_arm64.sh

# 自定义名称/版本
APP_NAME=FlClash_Muyu APP_VERSION=0.8.95 APP_BUILD_NUMBER=2026072102 \
  bash macos/packaging/release_arm64.sh

# Developer ID 签名（用于分发）
bash macos/packaging/release_arm64.sh \
  --identity "Developer ID Application: Example, Inc. (TEAMID)"

# Make 入口
make macos-release-arm64 SIGNING_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)"
```

产物：

- `build/macos/Build/Products/Release/FlClash.app` — 构建输出（无 PRE 标志）
- `dist/macos-arm64/FlClash-<version>.app.zip` — zip 包（带版本号，内部 .app 不带版本号）

### 调试构建

```bash
flutter build macos --debug
# 或
flutter run -d macos
```

注意：debug 构建右上角会显示 "DEBUG" 丝带；release 构建如果未传 `--dart-define=APP_ENV=stable` 会显示 "PRE" 丝带。

### 清理构建产物

```bash
flutter clean          # 清理 build/ 和 .dart_tool（~3.3 GB）
rm -rf dist/macos-arm64/*.app  # 清理旧归档文件
```

## 更多

- 完整卸载指南 `low-power-doc/uninstall-build-tools.md`
- CI 配置 `.github/workflows/build.yaml`（上游，不要修改）
