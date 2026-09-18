import SwiftUI
import Core

struct UsageMenuRow: View {
    let metric: UsageMetric
    let now: Date
    let options: UsageDisplayOptions
    var isCondensed = false

    var body: some View {
        switch metric.content {
        case .meter(let quota):
            meter(UsageMeterReading.of(quota, isSession: metric.isSession, at: now, options: options))
        case .value(let text, _, _):
            value(text)
        }
    }

    private func meter(_ reading: UsageMeterReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(metric.title)
                    .font(UsageScale.label)
                    .foregroundStyle(MenuInk.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let status = reading.status {
                    HStack(spacing: 4) {
                        if status.showsFlame {
                            Image(systemName: "flame.fill")
                                .font(UsageScale.supporting)
                                .foregroundStyle(MenuInk.critical)
                        }
                        if let text = status.text {
                            Text(text)
                                .font(UsageScale.supporting)
                                .foregroundStyle(MenuInk.secondary)
                        }
                    }
                    .lineLimit(1)
                }
            }
            UsageMeterBar(reading: reading)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reading.headline)
                    .foregroundStyle(MenuInk.primary)
                Spacer(minLength: 8)
                Text(reading.trailing)
                    .foregroundStyle(MenuInk.secondary)
            }
            .font(UsageScale.supporting)
            .monospacedDigit()
            .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.spoken(title: metric.title))
    }

    private func value(_ text: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(metric.title)
                .font(UsageScale.supporting.weight(.semibold))
                .foregroundStyle(MenuInk.primary)
            Spacer(minLength: 12)
            Text(text)
                .font(UsageScale.supporting)
                .foregroundStyle(MenuInk.primary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.top, isCondensed ? 2 : 6)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
    }
}

struct UsageMeterBar: View {
    let reading: UsageMeterReading
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(MenuInk.track)
                if reading.tone != .empty, reading.fill > 0 {
                    Capsule()
                        .fill(MenuInk.tone(reading.tone))
                        .frame(width: min(width, max(height, width * reading.fill)))
                }
            }
            .overlay(alignment: .leading) {
                if let tick = reading.paceTick {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(MenuInk.primary.opacity(0.55))
                        .frame(width: 2, height: height + 4)
                        .offset(x: min(max(width * tick - 1, 0), max(0, width - 2)))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

extension UsageMetric {
    var isText: Bool {
        if case .value = content { return true }
        return false
    }
}
