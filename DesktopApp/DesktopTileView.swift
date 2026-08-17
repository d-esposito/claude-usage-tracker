import SwiftUI

struct DesktopTileView: View {
    @ObservedObject var controller: DesktopUsageController

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            tile(at: timeline.date)
        }
        .frame(width: 382, height: 124)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .contextMenu {
            Button("Refresh Now") { Task { await controller.refresh() } }
            Divider()
            Button("Quit Claude Usage Tracker") { NSApp.terminate(nil) }
        }
    }

    private func tile(at now: Date) -> some View {
        Group {
            if let snapshot = controller.snapshot, !snapshot.limits.isEmpty {
                HStack(alignment: .center, spacing: 20) {
                    ForEach(snapshot.limits.prefix(3)) { limit in
                        DesktopGauge(limit: limit, now: now)
                            .frame(maxWidth: .infinity)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                loadingState
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.18), radius: 20, y: 9)
        .padding(4)
    }

    private var loadingState: some View {
        HStack(spacing: 20) {
            ForEach(["5 hr", "Weekly", "Model"], id: \.self) { label in
                VStack(spacing: 7) {
                    ZStack {
                        Circle().stroke(.primary.opacity(0.10), lineWidth: 9)
                        Text(label)
                            .font(.system(size: label.count > 5 ? 10 : 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary.opacity(0.38))
                    }
                    .frame(width: 64, height: 64)
                    Text(controller.errorMessage == nil ? "Loading…" : "Refresh failed")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.42))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .redacted(reason: controller.isRefreshing ? .placeholder : [])
    }
}

private struct DesktopGauge: View {
    let limit: UsageLimit
    let now: Date
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.14), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: max(0.012, limit.remainingPercent / 100))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: gaugeColor.opacity(0.22), radius: 5)
                Text(shortLabel)
                    .font(.system(size: shortLabel.count > 5 ? 10 : 13, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(.primary.opacity(0.92))
                    .padding(10)
                    .opacity(isHovered ? 0 : 1)
                    .scaleEffect(isHovered ? 0.86 : 1)

                Text("\(Int(limit.remainingPercent.rounded()))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary.opacity(0.94))
                    .opacity(isHovered ? 1 : 0)
                    .scaleEffect(isHovered ? 1 : 0.86)
            }
            .frame(width: 68, height: 68)
            .onHover { hovering in
                withAnimation(.snappy(duration: 0.22)) { isHovered = hovering }
            }

            Text(resetLabel)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.72))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(limit.title), \(Int(limit.remainingPercent.rounded())) percent remaining, \(resetLabel)")
        .help("\(Int(limit.remainingPercent.rounded()))% remaining")
    }

    private var shortLabel: String {
        switch limit.kind {
        case .session: "5 hr"
        case .weekly: "Weekly"
        case .model:
            limit.title.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces) ?? "Model"
        }
    }

    private var gaugeColor: Color {
        if limit.remainingPercent <= 10 { return Color(red: 1.0, green: 0.28, blue: 0.25) }
        if limit.remainingPercent <= 25 { return Color(red: 1.0, green: 0.64, blue: 0.17) }
        return Color(red: 0.18, green: 0.86, blue: 0.40)
    }

    private var resetLabel: String {
        guard let reset = limit.resetsAt else { return "No reset" }
        if reset <= now { return "Resetting" }
        return "Reset " + reset.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }
}
