import SwiftUI

@main
struct WatchPointerPhoneApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section {
                        Label("用 Apple Watch 操控 Mac", systemImage: "applewatch")
                        Text("此 iPhone 应用用于随附安装 WatchPointer 手表应用。日常操控由手表通过蓝牙直接连接 Mac。")
                    }
                    Section("1 · 安装到手表") {
                        Text("打开 iPhone 上的「Watch」应用，在「我的手表」→「可用 App」中找到 WatchPointer，轻点「安装」。若已自动安装，可直接在手表上打开。")
                    }
                    Section("2 · 连接 Mac") {
                        Text("在 Mac 上启动 WatchPointer 接收器，打开手表上的 WatchPointer，轻点 Mac 名称旁的 Pair。")
                    }
                    Section("3 · 开始操控") {
                        Text("在手表触控区滑动移动光标，轻点点击；按住不动片刻，再滑动即可拖拽，抬手释放。转动数码表冠滚动，无需转动手腕或校准。")
                    }
                }
                .navigationTitle("WatchPointer")
            }
        }
    }
}
