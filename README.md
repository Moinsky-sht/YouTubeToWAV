# YouTubeToWAV

输入 YouTube 链接，一键提取 WAV 无损音频。macOS 原生 App。

## 获取 .dmg 的方式

### 方式一：GitHub Actions（无需 Mac，推荐）

1. 把代码推送到你的 GitHub 仓库（新建或 fork 都行）
2. 在仓库页面点 **Actions** → **Build DMG** → **Run workflow**
3. 等几分钟，下载 Artifacts 里的 `YouTubeToWAV-dmg.zip`
4. 解压得到 `YouTubeToWAV.dmg`

### 方式二：本地 Xcode 编译

要求：macOS 14+，Xcode 15+

```bash
# 1. 装依赖
brew install yt-dlp ffmpeg

# 2. 用 Xcode 打开 Package.swift（或 File > Open... > 选择项目）
# 3. Product > Archive > Distribute App

# 或者命令行：
swift build -c release
```

## 首次使用

打开 App 前，确保已安装 yt-dlp 和 ffmpeg：

```bash
brew install yt-dlp ffmpeg
```

## 项目结构

```
YouTubeToWAV/
├── Package.swift                    # Swift 包配置
├── Sources/YouTubeToWAV/
│   ├── YouTubeToWAVApp.swift        # App 入口
│   ├── ContentView.swift            # UI（输入框 + 进度条 + 按钮）
│   ├── DownloadManager.swift        # 下载 & 转换逻辑
│   └── Resources/                   # 图标等资源
├── .github/workflows/
│   └── build-dmg.yml                # GitHub Actions 自动打包
└── README.md
```
