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
                        Text("将手表 12 点方向朝向屏幕中心，轻点 Center 校准。转动手表移动光标，轻点触控区点击，长按拖拽，转动数码表冠滚动。")
                    }
                }
                .navigationTitle("WatchPointer")
            }
        }
    }
}
