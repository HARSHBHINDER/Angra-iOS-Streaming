import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct LiveActivityBundle: WidgetBundle {
    var body: some Widget { StreamLiveActivity() }
}

/// The iOS "bubble": live timer plus Mute mic / Break / End in the Dynamic Island and on the Lock Screen.
struct StreamLiveActivity: Widget {
    private static let ember = Color(red: 0.95, green: 0.33, blue: 0.18)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreamActivity.self) { ctx in
            VStack(alignment: .leading, spacing: 12) {
                header(ctx)
                controls(ctx.state)
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { liveBadge }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: ctx.attributes.start...Date.distantFuture, countsDown: false)
                        .monospacedDigit().font(.headline).frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) { controls(ctx.state) }
            } compactLeading: {
                Image(systemName: "dot.radiowaves.left.and.right").foregroundStyle(.red)
            } compactTrailing: {
                Text(timerInterval: ctx.attributes.start...Date.distantFuture, countsDown: false)
                    .monospacedDigit().frame(maxWidth: 52)
            } minimal: {
                Image(systemName: ctx.state.micMuted ? "mic.slash.fill" : "dot.radiowaves.left.and.right")
                    .foregroundStyle(.red)
            }
        }
    }

    private var liveBadge: some View {
        Text("LIVE").font(.caption.weight(.heavy)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3).background(.red, in: Capsule())
    }

    private func header(_ ctx: ActivityViewContext<StreamActivity>) -> some View {
        HStack {
            liveBadge
            Text(ctx.attributes.channel).font(.headline).foregroundStyle(.white).lineLimit(1)
            Spacer()
            Text(timerInterval: ctx.attributes.start...Date.distantFuture, countsDown: false)
                .monospacedDigit().font(.headline).foregroundStyle(.white).frame(maxWidth: 90, alignment: .trailing)
        }
    }

    private func controls(_ s: StreamActivity.ContentState) -> some View {
        HStack(spacing: 10) {
            control(ToggleMicIntent(), s.micMuted ? "mic.slash.fill" : "mic.fill", s.micMuted ? "Unmute" : "Mute", on: s.micMuted)
            control(ToggleBreakIntent(), s.onBreak ? "play.fill" : "pause.fill",
                    s.onBreak ? "Resume" : "Break", on: s.onBreak)
            control(EndStreamIntent(), "stop.fill", "End", on: true)
        }
    }

    private func control(_ intent: some LiveActivityIntent, _ symbol: String, _ label: String, on: Bool) -> some View {
        Button(intent: intent) {
            Label(label, systemImage: symbol).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
        }
        .tint(on ? .red : Self.ember)
        .buttonStyle(.borderedProminent)
    }
}
