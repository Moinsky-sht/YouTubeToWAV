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
                return "未安装 yt-dlp\n请在终端运行: brew install yt-dlp"
            case .ffmpegNotInstalled:
                return "未安装 ffmpeg\n请在终端运行: brew install ffmpeg"
            case .invalidURL:
                return "请输入有效的 YouTube 链接"
            case .downloadFailed(let msg):
                return "下载失败: \(msg)"
            case .conversionFailed(let msg):
                return "转换失败: \(msg)"
            }
        }
    }

    // MARK: - 检查依赖

    func checkDependencies() async throws {
        guard try await checkCommand("yt-dlp") else {
            throw DownloadError.ytDlpNotInstalled
        }
        guard try await checkCommand("ffmpeg") else {
            throw DownloadError.ffmpegNotInstalled
        }
    }

    private func checkCommand(_ cmd: String) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", cmd]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    // MARK: - 从 YouTube 获取标题

    func fetchTitle(from url: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["yt-dlp", "--no-playlist", "--get-title", url]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw DownloadError.downloadFailed("无法获取视频信息")
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let title = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-") ?? "Unknown Title"

        return title
    }

    // MARK: - 下载并转换（流式进度）

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

        let downloadProcess = Process()
        downloadProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        downloadProcess.arguments = [
            "yt-dlp",
            "--no-playlist",
            "-f", "bestaudio",
            "-o", tempFile.path,
            url
        ]

        let downloadErrPipe = Pipe()
        downloadProcess.standardError = downloadErrPipe
        downloadProcess.standardOutput = Pipe()

        try downloadProcess.run()
        downloadProcess.waitUntilExit()

        guard downloadProcess.terminationStatus == 0, FileManager.default.fileExists(atPath: tempFile.path) else {
            let errData = downloadErrPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "未知错误"
            throw DownloadError.downloadFailed(errMsg)
        }

        progressHandler(0.6)

        // 2. 转 WAV
        let convertProcess = Process()
        convertProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        convertProcess.arguments = [
            "ffmpeg",
            "-y",
            "-i", tempFile.path,
            "-acodec", "pcm_s16le",
            wavFile.path
        ]

        let convertErrPipe = Pipe()
        convertProcess.standardError = convertErrPipe
        convertProcess.standardOutput = Pipe()

        try convertProcess.run()
        convertProcess.waitUntilExit()

        guard convertProcess.terminationStatus == 0, FileManager.default.fileExists(atPath: wavFile.path) else {
            let errData = convertErrPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "未知错误"
            throw DownloadError.conversionFailed(errMsg)
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
