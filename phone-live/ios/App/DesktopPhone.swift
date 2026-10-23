import SwiftUI
import Foundation
import Security
import CryptoKit
import LocalAuthentication
import ActivityKit

// Separate from the older hook client: desktop credentials never call /phone or MCP.
struct DesktopCredentials: Codable { var origin: String; var token: String; var deviceId: String; var fingerprint: String }
enum DesktopVault {
    static func query(_ account: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "OrbyLive.Desktop.v1", kSecAttrAccount as String: account] }
    static func data(_ account: String, context: LAContext? = nil) throws -> Data {
        var q = query(account); q[kSecReturnData as String] = true
        if let context { q[kSecUseAuthenticationContext as String] = context }
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let d = result as? Data else { throw PhoneError.message("Connection or protected signing key unavailable. Unlock your phone or reconnect.") }
        return d
    }
    static func put(_ account: String, _ data: Data, signing: Bool = false) throws {
        var q = query(account); SecItemDelete(q as CFDictionary); q[kSecValueData as String] = data
        if signing {
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .userPresence, &error) else { throw PhoneError.message("Set a screen-lock passcode before connecting.") }
            q[kSecAttrAccessControl as String] = access
        } else { q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly }
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw PhoneError.message("Could not save the protected phone connection.") }
    }
    static func load() throws -> DesktopCredentials { try JSONDecoder().decode(DesktopCredentials.self, from: data("connection")) }
    static func save(_ c: DesktopCredentials) throws { try put("connection", JSONEncoder().encode(c)) }
    static func makeKey() throws -> String {
        let key = P256.Signing.PrivateKey(); try put("signing", key.rawRepresentation, signing: true)
        return key.publicKey.x963Representation.base64EncodedString()
    }
    static func signature(_ text: String) throws -> String {
        let context = LAContext(); context.localizedReason = "Confirm this one AI permission decision"
        context.touchIDAuthenticationAllowableReuseDuration = 0
        let key = try P256.Signing.PrivateKey(rawRepresentation: data("signing", context: context))
        return try key.signature(for: Data(text.utf8)).derRepresentation.base64EncodedString()
    }
    static func clear() { for a in ["connection", "signing"] { SecItemDelete(query(a) as CFDictionary) } }
}
struct DesktopTask: Decodable, Identifiable { var id: String; var provider: String; var state: String; var title: String; var detail: String }
struct DesktopPending: Decodable, Identifiable { var id: String; var provider: String; var revision: String; var expiresAt: Int; var status: String }
struct DesktopFeed: Decodable { var connected: Bool; var active: Bool; var tasks: [DesktopTask]; var requests: [DesktopPending]; var message: String; var updatedAt: Int }
struct DesktopReview: Decodable { var id: String; var provider: String; var reviewText: String; var revision: String; var status: String; var expiresAt: Int }
enum DesktopService {
    static func origin(_ text: String) throws -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let u = URLComponents(string: clean), u.scheme == "https", u.host != nil, u.user == nil, u.password == nil, u.query == nil, u.fragment == nil, u.path.isEmpty else { throw PhoneError.message("Enter only the HTTPS relay address without a path.") }
        return clean
    }
    static func send<T: Decodable>(_ path: String, at base: String? = nil, body: [String: Any]? = nil, method: String? = nil) async throws -> T {
        var c: DesktopCredentials?
        if base == nil { c = try DesktopVault.load() }
        let address = try origin(base ?? c!.origin)
        guard path.hasPrefix("/mobile/"), !path.contains(".."), let url = URL(string: address + path) else { throw PhoneError.message("Invalid endpoint.") }
        var req = URLRequest(url: url); req.httpMethod = method ?? (body == nil ? "GET" : "POST"); req.timeoutInterval = 8
        if let c { req.setValue("Bearer \(c.token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body); req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: req)
        guard data.count <= 262144, let h = response as? HTTPURLResponse, (200..<300).contains(h.statusCode) else { throw PhoneError.message("The connection or request is unavailable. Refresh before trying again.") }
        return try JSONDecoder().decode(T.self, from: data)
    }
    struct Pair: Decodable { var token: String; var deviceId: String; var fingerprint: String; var computer: String }
    struct Recorded: Decodable { var recorded: Bool }
    struct Registered: Decodable { var registered: Bool }
    struct Revoked: Decodable { var revoked: Bool }
}

@MainActor final class DesktopPhoneModel: ObservableObject {
    @Published var credentials = try? DesktopVault.load()
    @Published var feed: DesktopFeed?
    @Published var message = ""
    @Published var reviewID: String?
    private var tokenTasks: [String: Task<Void, Never>] = [:]
    var liveState: OrbyAttributes.ContentState {
        let pending = feed?.requests.first, working = feed?.tasks.first(where: { $0.state == "working" })
        let online = feed?.connected == true
        return .init(provider: pending?.provider ?? working?.provider ?? "Orby", phase: !online ? "closed" : pending != nil ? "review" : working != nil ? "working" : "ready", text: !online ? "PC offline" : pending != nil ? "Permission requested" : working != nil ? "Working on your PC" : "All quiet", requestId: pending?.id ?? "", revision: pending?.revision ?? "", expiresAt: pending?.expiresAt ?? 0, pendingCount: feed?.requests.count ?? 0, updatedAt: feed?.updatedAt ?? 0)
    }
    func pair(_ origin: String, _ invitation: String, _ name: String) async {
        do {
            let address = try DesktopService.origin(origin), key = try DesktopVault.makeKey()
            let response: DesktopService.Pair = try await DesktopService.send("/mobile/pair", at: address, body: ["invite": invitation.trimmingCharacters(in: .whitespacesAndNewlines), "name": name, "publicKey": key])
            let fingerprint = SHA256.hash(data: Data(base64Encoded: key)!).map { String(format: "%02x", $0) }.joined().prefix(12).uppercased()
            guard fingerprint == response.fingerprint else { throw PhoneError.message("Phone fingerprint mismatch. Revoke this attempt on the PC.") }
            let c = DesktopCredentials(origin: address, token: response.token, deviceId: response.deviceId, fingerprint: fingerprint)
            try DesktopVault.save(c); credentials = c; message = "Compare this fingerprint with Orby on the PC, then trust this phone there."
            await refresh()
        } catch { message = error.localizedDescription }
    }
    func refresh() async {
        guard credentials != nil else { return }
        do {
            let next: DesktopFeed = try await DesktopService.send("/mobile/state"); feed = next
            for activity in Activity<OrbyAttributes>.activities { await activity.update(ActivityContent(state: liveState, staleDate: Date().addingTimeInterval(90))) }
        } catch { feed = nil; message = "PC feed unavailable. No current task or permission status." }
    }
    func watchActivities() async {
        for activity in Activity<OrbyAttributes>.activities { observe(activity) }
        for await activity in Activity<OrbyAttributes>.activityUpdates { observe(activity) }
    }
    private func observe(_ activity: Activity<OrbyAttributes>) {
        guard tokenTasks[activity.id] == nil else { return }
        tokenTasks[activity.id] = Task { [weak self] in
            for await data in activity.pushTokenUpdates {
                if Task.isCancelled { return }
                do { let _: DesktopService.Registered = try await DesktopService.send("/mobile/activity", body: ["token": data.map { String(format: "%02x", $0) }.joined()]) }
                catch { self?.message = "Live Activity push could not be registered. Open the app to check the feed." }
            }
        }
    }
    func start() async {
        do {
            await refresh()
            guard feed?.active == true else { throw PhoneError.message("Confirm this phone on the PC first.") }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw PhoneError.message("Enable Orby Live Activities in iPhone Settings.") }
            for a in Activity<OrbyAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            let a = try Activity.request(attributes: OrbyAttributes(name: "My PC"), content: ActivityContent(state: liveState, staleDate: Date().addingTimeInterval(90)), pushType: .token)
            observe(a); message = "Live Activity started. Remote updates require the relay's Apple push configuration. Renew within eight hours."
        } catch { message = error.localizedDescription }
    }
    func disconnect() async {
        do {
            let _: DesktopService.Revoked = try await DesktopService.send("/mobile/pair", method: "DELETE")
            for a in Activity<OrbyAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
            tokenTasks.values.forEach { $0.cancel() }; tokenTasks.removeAll()
            DesktopVault.clear(); credentials = nil; feed = nil; message = "Phone disconnected."
        } catch { message = "Could not revoke this phone. Try again online, or revoke it in Orby on the PC." }
    }
}
struct DesktopPhoneHome: View {
    @EnvironmentObject var model: DesktopPhoneModel
    @State private var origin = ""
    @State private var invite = ""
    @State private var name = "My iPhone"
    @State private var busy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { OrbyFace(provider: model.liveState.provider, sleeping: model.liveState.phase == "ready", attention: model.liveState.pendingCount > 0); VStack(alignment: .leading) { Text("Orby Live").font(.largeTitle.bold()); Text("Your PC, within reach").foregroundStyle(.secondary) } }
                    if let c = model.credentials {
                        Text("Phone fingerprint: \(c.fingerprint)").font(.headline).textSelection(.enabled)
                        Text("Match this code with Orby on the PC before trusting this phone.").font(.footnote).foregroundStyle(.secondary)
                        if let feed = model.feed {
                            Text(feed.message).foregroundStyle(.secondary)
                            ForEach(feed.requests) { r in Button { model.reviewID = r.id } label: { Label("\(r.provider) · review exact request", systemImage: "lock.shield") }.buttonStyle(.borderedProminent) }
                            ForEach(feed.tasks) { t in
                                HStack(alignment: .top, spacing: 14) { OrbyFace(provider: t.provider, sleeping: t.state == "idle", attention: t.state == "attention"); VStack(alignment: .leading, spacing: 5) { Text("\(t.provider) · \(t.state)").font(.caption).foregroundStyle(.secondary); Text(t.title).font(.headline); Text(t.detail).font(.subheadline).foregroundStyle(.secondary) } }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                            }
                            if feed.active && feed.connected && feed.tasks.isEmpty && feed.requests.isEmpty { Text("No readable active tasks").font(.title2) }
                        }
                        Button("Start / renew Live Activity") { work { await model.start() } }.buttonStyle(.borderedProminent)
                        Text("Live Activities are time-limited by iOS, and delivery can be delayed. Open Orby Live to check current requests. A permission always opens an exact review and asks for your screen lock before it is signed.").font(.footnote).foregroundStyle(.secondary)
                        Button("Disconnect this phone", role: .destructive) { work { await model.disconnect() } }
                    } else {
                        Text("In Orby on Windows, open Settings → Phone access. Create a five-minute invitation. Keep your PC online.")
                        TextField("HTTPS relay address", text: $origin).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Five-minute invitation", text: $invite).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Phone name", text: $name)
                        Button("Connect phone") { work { await model.pair(origin, invite, name); invite = "" } }.buttonStyle(.borderedProminent)
                    }
                    if busy { ProgressView() }
                    if !model.message.isEmpty { Text(model.message).font(.footnote).foregroundStyle(.secondary) }
                    Text("Task activity: ChatGPT, Claude, Gemini. Remote approval: supported ChatGPT/Codex permission cards only. Other prompts stay on your PC.").font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }.navigationTitle("Companion").navigationBarTitleDisplayMode(.inline).disabled(busy)
            .sheet(isPresented: Binding(get: { model.reviewID != nil }, set: { if !$0 { model.reviewID = nil } })) { if let id = model.reviewID { DesktopReviewScreen(id: id).environmentObject(model) } }
            .task { while !Task.isCancelled { await model.refresh(); try? await Task.sleep(for: .seconds(3)) } }
        }
    }
    private func work(_ action: @escaping @MainActor () async -> Void) { busy = true; Task { await action(); busy = false } }
}
struct DesktopReviewScreen: View {
    let id: String
    @EnvironmentObject var model: DesktopPhoneModel
    @State private var detail: DesktopReview?
    @State private var read = false
    @State private var busy = false
    @State private var message = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Review exact action").font(.title.bold())
                    Text("This is untrusted request text from the AI. Read the complete action before answering.").font(.footnote).foregroundStyle(.secondary)
                    if let d = detail {
                        Text(d.reviewText).font(.system(.body, design: .monospaced)).textSelection(.enabled).padding().background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let active = d.status == "pending" && d.expiresAt > Int(context.date.timeIntervalSince1970)
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Status: \(d.status) · \(max(0, d.expiresAt - Int(context.date.timeIntervalSince1970)))s remaining").font(.caption)
                                Toggle("I have read the complete action", isOn: $read)
                                HStack { Button("Deny", role: .destructive) { decide("deny", d) }.buttonStyle(.bordered); Spacer(); Button("Allow once") { decide("allow", d) }.buttonStyle(.borderedProminent).disabled(!read) }.disabled(!active || busy)
                            }
                        }
                    } else { ProgressView("Loading exact action…") }
                    if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    Text("A recorded decision is waiting for the PC. Submitted/resolved means the PC handled the prompt; it does not confirm the requested action executed.").font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }.navigationTitle("Permission").navigationBarTitleDisplayMode(.inline).toolbar { Button("Close") { model.reviewID = nil }.disabled(busy) }
            .task { while !Task.isCancelled { await load(); try? await Task.sleep(for: .seconds(3)) } }
        }
    }
    private func load() async {
        do {
            let d: DesktopReview = try await DesktopService.send("/mobile/request/\(id)")
            let hash = SHA256.hash(data: Data(d.reviewText.utf8)).map { String(format: "%02x", $0) }.joined()
            guard d.id == id, hash == d.revision else { detail = nil; throw PhoneError.message("Request text did not match its fingerprint.") }
            if detail?.revision != d.revision { read = false }; detail = d
        } catch { detail = nil; message = error.localizedDescription }
    }
    private func decide(_ decision: String, _ d: DesktopReview) {
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                let c = try DesktopVault.load(), nonce = UUID().uuidString.lowercased()
                let canonical = "OrbyPhone.v1\n\(c.deviceId)\n\(d.id)\n\(d.revision)\n\(decision)\n\(nonce)\n\(d.expiresAt)"
                // Keychain gates retrieval of the signing key on fresh device-owner authentication.
                let signature = try await Task.detached { try DesktopVault.signature(canonical) }.value
                guard d.expiresAt > Int(Date().timeIntervalSince1970) else { throw PhoneError.message("Request expired. Nothing sent.") }
                let _: DesktopService.Recorded = try await DesktopService.send("/mobile/request/\(id)/decision", body: ["revision": d.revision, "decision": decision, "nonce": nonce, "expiresAt": d.expiresAt, "signature": signature])
                read = false; message = "Decision recorded. Waiting for PC acknowledgement."
                await load(); await model.refresh()
            } catch { message = error.localizedDescription; await load() }
        }
    }
}
