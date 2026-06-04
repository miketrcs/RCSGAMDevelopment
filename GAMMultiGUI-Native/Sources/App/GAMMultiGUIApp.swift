import SwiftUI

extension Notification.Name {
    static let showGAMSetupHelp = Notification.Name("showGAMSetupHelp")
    static let showCSVHelp = Notification.Name("showCSVHelp")
    static let showAbout = Notification.Name("showAbout")
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
            CommandGroup(replacing: .appInfo) {
                Button("About GAMIT") {
                    NotificationCenter.default.post(name: .showAbout, object: nil)
                }
            }
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
