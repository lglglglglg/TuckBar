import SwiftUI

struct AggregatePanelView: View {
    let items: [MenuBarItemDescriptor]
    let activate: (MenuBarItemDescriptor) -> Void
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            if items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("暂无收纳的图标")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let onOpenSettings {
                        Button("去设置", action: onOpenSettings)
                            .font(.system(size: 12, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(items) { item in
                            MenuBarItemButton(item: item) {
                                activate(item)
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(width: contentWidth, height: 38)

                if let onOpenSettings {
                    Divider()
                        .frame(height: 18)
                        .opacity(0.3)

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("偏好设置")
                    .padding(.trailing, 6)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.20), radius: 14, x: 0, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
        }
        .fixedSize()
    }

    private var contentWidth: CGFloat {
        let itemWidths = items.reduce(CGFloat.zero) { total, item in
            total + max(item.frame.width, 24) + 6 + 4
        }
        return min(max(itemWidths + 14, 60), 780)
    }
}

private struct MenuBarItemButton: View {
    let item: MenuBarItemDescriptor
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            action()
        }) {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: iconWidth, height: iconHeight)
                .frame(width: iconWidth + 6, height: 34)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.14) : Color.clear)
                }
                .scaleEffect(isHovering ? 1.05 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovering)
        }
        .buttonStyle(.plain)
        .help(item.displayName)
        .onHover { isHovering = $0 }
    }

    private var iconWidth: CGFloat {
        max(item.frame.width, 22)
    }

    private var iconHeight: CGFloat {
        // Native macOS status bar icon height is 22px
        min(max(item.frame.height > 0 ? item.frame.height : 22, 22), 24)
    }
}
