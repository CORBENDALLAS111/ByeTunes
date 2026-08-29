import SwiftUI
import WidgetKit
import ActivityKit

private func downloadAccentColor(for phase: DownloadLiveActivityAttributes.Phase) -> Color {
    switch phase {
    case .completed, .allCompleted:
        return .green
    case .failed, .cancelled:
        return .red
    case .paused:
        return .orange
    default:
        return .blue
    }
}

private func headline(for state: DownloadLiveActivityAttributes.ContentState) -> String {
    if let first = state.items.first {
        return state.items.count > 1 ? "\(first.trackName) +\(state.items.count - 1) more" : first.trackName
    }
    switch state.phase {
    case .completed, .allCompleted:
        return "All downloads complete"
    case .cancelled:
        return "Download cancelled"
    case .failed:
        return "Download failed"
    default:
        return "Downloading"
    }
}

private func aggregatePercentText(for state: DownloadLiveActivityAttributes.ContentState) -> String {
    guard !state.items.isEmpty else {
        return (state.phase == .completed || state.phase == .allCompleted) ? "100%" : "0%"
    }
    let average = state.items.map(\.progress).reduce(0, +) / Double(state.items.count)
    return "\(Int((average * 100).rounded()))%"
}

private struct DownloadLiveActivityView: View {
    let state: DownloadLiveActivityAttributes.ContentState

    var body: some View {
        DownloadActivityCard(state: state, isCompact: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

private struct DownloadItemRow: View {
    let item: DownloadLiveActivityAttributes.ActiveItem
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.trackName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 6)
                Text("\(Int((item.progress * 100).rounded()))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: item.progress)
                .tint(accent)
        }
    }
}

private struct DownloadActivityCard: View {
    let state: DownloadLiveActivityAttributes.ContentState
    let isCompact: Bool

    private var accent: Color { downloadAccentColor(for: state.phase) }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 7 : 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline(for: state))
                        .font(isCompact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let only = state.items.first, state.items.count == 1 {
                        Text(only.artistName)
                            .font(isCompact ? .caption : .subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 5) {
                        if state.phase == .completed || state.phase == .allCompleted {
                            Image(systemName: state.phase == .allCompleted ? "sparkles" : "checkmark.circle.fill")
                                .foregroundStyle(accent)
                                .scaleEffect(state.phase == .allCompleted ? 1.14 : 1.08)
                                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: state.phase)
                        }
                        Text(state.queueText)
                            .font(isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text(state.speedText)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if state.items.count > 1 {
                VStack(spacing: 6) {
                    ForEach(state.items.prefix(3), id: \.trackName) { item in
                        DownloadItemRow(item: item, accent: accent)
                    }
                }
            } else {
                ProgressView(value: state.items.first?.progress ?? ((state.phase == .completed || state.phase == .allCompleted) ? 1 : 0))
                    .tint(accent)
            }

            HStack(spacing: 8) {
                Text(state.statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 8)
                if state.items.count <= 1 {
                    Text(aggregatePercentText(for: state))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DownloadIslandBottomView: View {
    let state: DownloadLiveActivityAttributes.ContentState

    private var accent: Color { downloadAccentColor(for: state.phase) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if state.items.count > 1 {
                ForEach(state.items.prefix(3), id: \.trackName) { item in
                    DownloadItemRow(item: item, accent: accent)
                }
            } else {
                ProgressView(value: state.items.first?.progress ?? ((state.phase == .completed || state.phase == .allCompleted) ? 1 : 0))
                    .tint(accent)
                    .controlSize(.mini)
            }

            HStack(spacing: 8) {
                Text(state.statusText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 6)

                if state.items.count <= 1 {
                    Text(aggregatePercentText(for: state))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DownloadLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadLiveActivityAttributes.self) { context in
            DownloadLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(headline(for: context.state))
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        if let only = context.state.items.first, context.state.items.count == 1 {
                            Text(only.artistName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                        }
                    }
                    .padding(.leading, 12)
                    .frame(maxWidth: 145, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(aggregatePercentText(for: context.state))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                        Text(context.state.queueText)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(context.state.speedText)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 12)
                    .frame(maxWidth: 70, alignment: .trailing)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    DownloadIslandBottomView(state: context.state)
                        .padding(.horizontal, 12)
                }
            } compactLeading: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle((context.state.phase == .completed || context.state.phase == .allCompleted) ? .green : .blue)
            } compactTrailing: {
                EmptyView()
            } minimal: {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle((context.state.phase == .completed || context.state.phase == .allCompleted) ? .green : .blue)
            }
            .widgetURL(URL(string: "byetunes://download"))
            .keylineTint((context.state.phase == .completed || context.state.phase == .allCompleted) ? .green : .blue)
        }
    }
}

@main
struct MusicManagerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivityWidget()
    }
}
