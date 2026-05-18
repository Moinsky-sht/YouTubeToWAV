import Foundation
import AppKit

actor DownloadManager {

    enum DownloadError: LocalizedError {
        case ytDlpNotInstalled
        case ffmpegNotInstalled
        case invalidURL
        case downloadFailed(String)
        case conversionFailed(String)

        var errorDescription: String? {
            switch self {
            case .ytDlpNotInstalled:
                return "未找到 yt-dlp，请通过 Homebrew 安装:\nbrew install yt-dlp"
            case .ffmpegNotInstalled:
                return "未找到 ffmpeg，请通过 Homebrew 安装:\nbrew install ffmpeg"
            case .invalidURL:
                return "请输入有效的 YouTube 链接"
            case .downloadFailed(let msg):
                return "下载失败: \(msg)"
            case .conversionFailed(let msg):
                return "转换失败: \(msg)"
            }
        }
    }

    // MARK: - 查找可执行文件

    private func executablePath(_ name: String) -> URL? {
        // 1. 先找 bundle 里的（打包进 .app 的）
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "bin") {
            return bundled
        }

        // 2. 直接检查常见 Homebrew 路径
        //    （macOS GUI App 默认 PATH 不包含 /opt/homebrew/bin）
        let homebrewPaths = [
            "/opt/homebrew/bin/\(name)",   // Apple Silicon Mac
            "/usr/local/bin/\(name)",       // Intel Mac
        ]
        for path in homebrewPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // 3. 通过 which 查找 PATH（终端运行时可工作）
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch { }
        return nil
    }

    // MARK: - 检查依赖

    func checkDependencies() async throws {
        guard executablePath("yt-dlp") != nil else {
            throw DownloadError.ytDlpNotInstalled
        }
        guard executablePath("ffmpeg") != nil else {
            throw DownloadError.ffmpegNotInstalled
        }
    }

    // MARK: - 运行命令

    @discardableResult
    private func runCommand(
        _ executable: String,
        arguments: [String],
        captureOutput: Bool = false
    ) async throws -> (status: Int32, output: String) {
        guard let execURL = executablePath(executable) else {
            throw DownloadError.downloadFailed("找不到可执行文件: \(executable)")
        }

        let process = Process()
        process.executableURL = execURL
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return (process.terminationStatus, output + errorOutput)
    }

    // MARK: - 从 YouTube 获取标题

    func fetchTitle(from url: String) async throws -> String {
        let (status, output) = try await runCommand("yt-dlp", arguments: [
            "--no-playlist", "--get-title", url
        ])

        guard status == 0 else {
            throw DownloadError.downloadFailed(output)
        }

        let title = output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        return title.isEmpty ? "Unknown Title" : title
    }

    // MARK: - 下载并转换

    func downloadAndConvert(
        url: String,
        title: String,
        outputDir: URL,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {

        let outputFolder = outputDir.appendingPathComponent(title)
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let tempFile = outputFolder.appendingPathComponent("\(title).webm")
        let wavFile = outputFolder.appendingPathComponent("\(title).wav")

        // 1. 下载
        progressHandler(0.1)

        let (dlStatus, dlOutput) = try await runCommand("yt-dlp", arguments: [
            "--no-playlist",
            "-f", "bestaudio",
            "-o", tempFile.path,
            url
        ])

        guard dlStatus == 0, FileManager.default.fileExists(atPath: tempFile.path) else {
            throw DownloadError.downloadFailed(dlOutput)
        }

        progressHandler(0.6)

        // 2. 转 WAV
        let (cvStatus, cvOutput) = try await runCommand("ffmpeg", arguments: [
            "-y",
            "-i", tempFile.path,
            "-acodec", "pcm_s16le",
            wavFile.path
        ])

        guard cvStatus == 0, FileManager.default.fileExists(atPath: wavFile.path) else {
            throw DownloadError.conversionFailed(cvOutput)
        }

        progressHandler(0.95)

        // 3. 删除临时 .webm
        try? FileManager.default.removeItem(at: tempFile)

        progressHandler(1.0)

        return wavFile
    }

    // MARK: - 在 Finder 中打开

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
