# FlClash Low-Power

FlClash 低功耗 Fork，基于 [chen08209/FlClash](https://github.com/chen08209/FlClash) v0.8.94，面向 macOS 长时间后台运行优化。

## 合入的 PR

| 来源 | 内容 |
|------|------|
| #2201 | 托盘标题去重，关闭网速时取消流量订阅 |
| #2186 部分 | 隐藏窗口暂停每秒核心 IPC + 流量日志静默 |
| #1826 | 点击托盘图标切换显示/隐藏 |
| #2237 | TUN `auto-detect-interface` JSON 序列化修复 |
| #2238 | 关闭 IPv6 时清除 TUN IPv6 地址 |
| #2170 | 取消 99 小时运行时间上限 |

### 自研改动

| 内容 |
|------|
| 停止代理后延迟 10 秒再清流量（可确认本次流量后再归零） |
| 低功耗定时器检查：窗口隐藏 + 关闭网速 → 跳过每秒 core IPC |
| `resetTraffic` 全链路 async，防止重启时异步竞态 |
| Provider dispose 时取消定时器 |
| 关于页显示 "由 Muyu 修改后构建"，添加 Muyu 贡献者 |
| 副模块 URL HTTPS（无需 SSH key） |
| `.gitignore` 忽略 `**/.gradle/` |

## 分支布局

```
Muyu-Chen/FlClash-Low-Power (fork):
  main     → 低功耗版（即本分支），clone 即可编译
  upstream → 上游 main 镜像，用于 diff/对照

本地:
  macos-low-power → 开发分支，所有改动在此
```

## 合入上游新版本

上游发布新 tag（如 `v0.9.0`）后：

```bash
# 1. 拉取上游
git fetch origin --tags

# 2. 把 low-power 改动 rebase 到新 tag 上
git rebase --onto v0.9.0 v0.8.94 macos-low-power

# 3. 解决冲突（如有）后编译验证
bash macos/packaging/release_arm64.sh

# 4. 推送
git push my-fork macos-low-power:main --force
git push my-fork origin/main:refs/heads/upstream
```

README.md 只有一行指向本文档的链接——合上游时最多处理这一行冲突。

## 编译

需要 Xcode + Flutter 3.44+ + Go + Rust (rustup) + CocoaPods。

```bash
# 初始化
git submodule update --init --recursive  # 已 HTTPS URL，无需 SSH key
fvm use 3.44.4 --skip-pub-get            # FVM 固定版本
fvm flutter pub get
dart run build_runner build

# 编译 macOS Release（Apple Silicon only，无 PRE 标志）
bash macos/packaging/release_arm64.sh

# 产物
dist/macos-arm64/FlClash-0.8.95.app.zip  → FlClash.app
```

详细环境安装和卸载见 `low-power-doc/`。

## 与上游 dist 产物的区别

| 项目 | 上游 | Low-Power Fork |
|------|------|----------------|
| 右上角 PRE 标志 | 有 | 无（`APP_ENV=stable`） |
| 托盘标题每秒刷新 | 是 | 去重，不变不调 |
| 窗口隐藏时每秒 core IPC | 是 | 暂停 |
| 流量日志每秒写入 | 是 | 静默 |
| 停止代理后流量归零 | 立即 | 延迟 10 秒 |
| 运行时间上限 | 99:59:59 | 无 |
| macOS 框架 | 含 x86_64 | Apple Silicon only |
| TUN auto-detect-interface | JSON 键名错误 | 修复 |
| TUN IPv6 残留 | 关闭后仍残留 | 清除 |
