import SwiftUI

extension Notification.Name {
    static let showGAMSetupHelp = Notification.Name("showGAMSetupHelp")
    static let showCSVHelp = Notification.Name("showCSVHelp")
}

@main
struct GAMMultiGUIApp: App {
    var body: some Scene {
        WindowGroup("GAMIT") {
            RootView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("GAM Setup Help") {
                    NotificationCenter.default.post(name: .showGAMSetupHelp, object: nil)
                }
                Button("CSV File Guidance") {
                    NotificationCenter.default.post(name: .showCSVHelp, object: nil)
                }
            }
        }
    }
}
