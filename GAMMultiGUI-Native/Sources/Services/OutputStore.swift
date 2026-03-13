import Foundation

@MainActor
final class OutputStore: ObservableObject {
    @Published private(set) var text = ""

    func append(_ line: String) {
        text += line
        if !line.hasSuffix("\n") {
            text += "\n"
        }
    }

    func clear() {
        text = ""
    }
}
