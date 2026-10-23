import SwiftUI
import ActivityKit
import LocalAuthentication

@main struct OrbyLiveApp: App {
    @StateObject private var model = DesktopPhoneModel()
    var body: some Scene {
        WindowGroup {
            DesktopPhoneHome().environmentObject(model).preferredColorScheme(.dark)
                .onOpenURL { url in
                    guard url.scheme == "orbylive", url.host == "review",
                          let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let id = parts.queryItems?.first(where: { $0.name == "id" })?.value,
                          UUID(uuidString: id) != nil else { return }
                    model.reviewID = id
                }
                .task { await model.watchActivities() }
        }
    }
}
