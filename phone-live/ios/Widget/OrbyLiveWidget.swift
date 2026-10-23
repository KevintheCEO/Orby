import ActivityKit
import WidgetKit
import SwiftUI

@main struct OrbyLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrbyAttributes.self) { context in
            HStack(spacing: 12) {
                OrbyFace(provider: context.state.provider, sleeping: context.state.phase == "ready", attention: context.state.pendingCount > 0)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.provider).font(.headline)
                    Text(context.isStale ? "Feed out of date · open to refresh" : context.state.text).font(.subheadline).foregroundStyle(.secondary)
                    if context.state.pendingCount > 0 { Text("\(context.state.pendingCount) request(s) · tap to review").font(.caption).foregroundStyle(.orange) }
                }
                Spacer(minLength: 0)
                if context.state.pendingCount > 0 { Image(systemName: "lock.shield").foregroundStyle(.orange) }
            }.padding(16).activityBackgroundTint(.black).activitySystemActionForegroundColor(.white)
                .widgetURL(reviewURL(context.state.requestId))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { OrbyFace(provider: context.state.provider, attention: context.state.pendingCount > 0) }
                DynamicIslandExpandedRegion(.trailing) { Image(systemName: context.state.pendingCount > 0 ? "lock.shield" : "sparkles").padding(10).foregroundStyle(context.state.pendingCount > 0 ? .orange : .white) }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(context.state.provider).font(.headline)
                        Text(context.isStale ? "Open to refresh" : context.state.text).font(.caption)
                        if context.state.pendingCount > 0 { Link("Review exact request", destination: reviewURL(context.state.requestId)).font(.headline).foregroundStyle(.orange) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                }
            } compactLeading: {
                OrbyFace(provider: context.state.provider, sleeping: context.state.phase == "ready", attention: context.state.pendingCount > 0).scaleEffect(0.44).frame(width: 22, height: 22)
            } compactTrailing: {
                Image(systemName: context.state.pendingCount > 0 ? "lock.shield.fill" : "ellipsis").foregroundStyle(context.state.pendingCount > 0 ? .orange : .white)
            } minimal: {
                OrbyFace(provider: context.state.provider, attention: context.state.pendingCount > 0).scaleEffect(0.44).frame(width: 22, height: 22)
            }.widgetURL(reviewURL(context.state.requestId)).keylineTint(.white.opacity(0.25))
        }
    }
    private func reviewURL(_ id: String) -> URL {
        // Only opaque request IDs appear in the lock-screen URL; credentials stay in Keychain.
        URL(string: UUID(uuidString: id) == nil ? "orbylive://home" : "orbylive://review?id=\(id)")!
    }
}
