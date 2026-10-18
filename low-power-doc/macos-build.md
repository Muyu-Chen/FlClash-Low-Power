# macOS 构建与发布

本文档为独立笔记，不影响上游 README 或 CI 配置，方便持续合并。

## 环境

- macOS 26 (Apple Silicon) + Xcode 26
- Flutter 3.47.7（自带 Dart 3.13.5），见 `.fvmrc`；上游 CI 使用 Flutter 3.47.6
- Go 1.27.2、Rust 1.99.1；macOS 插件改用 Swift Package Manager

### 安装与升级

```bash
brew install --cask flutter
brew install go rustup
brew upgrade --cask flutter
brew upgrade go rustup
rustup toolchain install 1.99.1 --profile minimal --component rustfmt
rustup default 1.99.1
brew link --force rustup
```

本机使用 Homebrew 的 Flutter、Go 和 rustup。Rust SDK 由 rustup 管理并固定到项目的 1.99.1，不重复安装 Homebrew Rust。
项目 `.fvm/` 仅保存 SDK 链接，不单独存放 Flutter。

```bash
brew cleanup flutter go rustup
```

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
APP_NAME=FlClash_Muyu APP_VERSION=0.9.1 APP_BUILD_NUMBER=2026101702 \
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
flutter build macos --debug --dart-define=SAFE_MODE=true
flutter run -d macos --dart-define=SAFE_MODE=true
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
