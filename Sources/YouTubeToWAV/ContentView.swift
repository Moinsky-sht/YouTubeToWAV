import SwiftUI

struct ContentView: View {

    @State private var urlString: String = ""
    @State private var isDownloading = false
    @State private var progress: Double = 0
    @State private var statusText: String = "就绪"
    @State private var outputFile: URL?
    @State private var errorMessage: String?
    @State private var showError = false

    private let downloadManager = DownloadManager()
    private let outputDir: URL = {
        let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("YouTubeToWAV", isDirectory: true)
    }()

    var body: some View {
        VStack(spacing: 20) {
            // 标题区
            VStack(spacing: 4) {
                Image(systemName: "music.note.tv")
                    .font(.system(size: 36))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Text("YouTube → WAV")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("输入链接，提取无损音频")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // 输入框
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.secondary)
                TextField("粘贴 YouTube 链接...", text: $urlString)
                    .textFieldStyle(.plain)
                    .disabled(isDownloading)
                    .onSubmit { startDownload() }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )

            // 进度区
            if isDownloading {
                ProgressView(value: progress) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .progressViewStyle(.linear)
                .frame(maxWidth: .infinity)
            } else {
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 按钮区
            HStack(spacing: 12) {
                if let file = outputFile {
                    Button(action: { revealInFinder(file) }) {
                        Label("在 Finder 中显示", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button(action: startDownload) {
                    if isDownloading {
                        Label("下载中...", systemImage: "arrow.down.circle")
                    } else {
                        Label("提取 WAV", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty || isDownloading)
            }
        }
        .padding(24)
        .alert("出错了", isPresented: $showError) {
            Button("好的") { }
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    // MARK: - Actions

    private func startDownload() {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard URL(string: trimmed) != nil else {
            errorMessage = "请输入有效的 URL"
            showError = true
            return
        }

        isDownloading = true
        progress = 0
        statusText = "检查依赖..."
        outputFile = nil

        Task {
            do {
                // 1. 检查依赖
                try await downloadManager.checkDependencies()

                // 2. 获取标题
                statusText = "获取视频信息..."
                let title = try await downloadManager.fetchTitle(from: trimmed)

                // 3. 下载并转换
                statusText = "下载并转换为 WAV..."
                let wavFile = try await downloadManager.downloadAndConvert(
                    url: trimmed,
                    title: title,
                    outputDir: outputDir,
                    progressHandler: { p in
                        Task { @MainActor in
                            progress = p
                            if p < 0.6 {
                                statusText = "正在下载..."
                            } else if p < 0.95 {
                                statusText = "正在转换为 WAV..."
                            } else {
                                statusText = "清理临时文件..."
                            }
                        }
                    }
                )

                // 4. 完成
                outputFile = wavFile
                statusText = "✓ 完成！\(wavFile.lastPathComponent)"
                isDownloading = false
                progress = 1.0

            } catch let error as DownloadManager.DownloadError {
                errorMessage = error.localizedDescription
                showError = true
                isDownloading = false
                statusText = "就绪"
                progress = 0
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                isDownloading = false
                statusText = "就绪"
                progress = 0
            }
        }
    }

    private func revealInFinder(_ url: URL) {
        Task {
            await downloadManager.revealInFinder(url)
        }
    }
}

#Preview {
    ContentView()
}
