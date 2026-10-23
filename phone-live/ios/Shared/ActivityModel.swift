import ActivityKit
import Foundation

struct OrbyAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var provider: String
        var phase: String
        var text: String
        var requestId: String
        var revision: String
        var expiresAt: Int
        var pendingCount: Int
        var updatedAt: Int
        static let ready = ContentState(provider: "Orby Live", phase: "ready", text: "Ready", requestId: "", revision: "", expiresAt: 0, pendingCount: 0, updatedAt: Int(Date().timeIntervalSince1970))
    }
    var name: String
}
