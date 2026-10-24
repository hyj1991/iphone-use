import SwiftUI

/// An explicit export of the daemon credential, separate from device QR pairing.
@MainActor
struct LocalControlComputerConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var error: String?

    var body: some View {
        AppNavigationStack {
            Form {
                Section("连接电脑") {
                    Text("电脑和这台 iPhone 连接同一 Wi-Fi。在 TRAE 的命令面板选择“iPhone: Connect to Phone Use”，导入连接文件，再选择 iphone-use-mcp 程序。")
                    Text("文件包含操作这台手机的长期凭据。只传给你信任的电脑，导入后删除文件；不要上传到聊天、代码仓库或共享网盘。停止本机控制可以立即停止网络访问。")
                        .foregroundStyle(.secondary)
                    if let exportURL {
                        AppShareLink(item: exportURL) {
                            Label("发送连接文件到电脑", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("生成电脑连接文件") { prepareExport() }
                    }
                    if let error { Text(error).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("连接 TRAE")
            .toolbar { Button("完成") { dismiss() } }
        }
        .onDisappear { removeExport() }
    }

    private func prepareExport() {
        error = nil
        guard let address = LocalControlConnectionCodeView.wifiAddress() else {
            error = "请先连接 Wi-Fi。"; return
        }
        // Never generate a new secret here: export only the already configured daemon token.
        guard let data = ProtectedStore.read("daemon_token"),
              let token = String(data: data, encoding: .utf8),
              token.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
            error = "请先启用本机控制，再导出连接文件。"; return
        }
        do {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("phone-use-connection-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                     attributes: [.protectionKey: FileProtectionType.complete])
            let url = directory.appendingPathComponent("phone-use-connection.json")
            let contents: [String: Any] = [
                "version": 1, "backend": "iphone-self-host",
                "endpoint": "http://\(address):18787", "agentToken": token
            ]
            let encoded = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
            try encoded.write(to: url, options: [.atomic, .completeFileProtection])
            exportURL = url
        } catch {
            self.error = "无法生成连接文件，请稍后重试。"
        }
    }

    private func removeExport() {
        if let exportURL {
            try? FileManager.default.removeItem(at: exportURL.deletingLastPathComponent())
        }
        exportURL = nil
    }
}
