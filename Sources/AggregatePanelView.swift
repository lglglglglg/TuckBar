import SwiftUI

struct AggregatePanelView: View {
    let items: [MenuBarItemDescriptor]
    let activate: (MenuBarItemDescriptor) -> Void

    var body: some View {
        Group {
            if items.isEmpty {
                Label("尚未选择隐藏项目", systemImage: "menubar.rectangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .frame(height: 46)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(items) { item in
                            MenuBarItemButton(item: item) {
                                activate(item)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(width: contentWidth, height: max(38, (items.map(\.frame.height).max() ?? 33) + 8))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        }
        .fixedSize()
    }

    private var contentWidth: CGFloat {
        let itemWidths = items.reduce(CGFloat.zero) { total, item in
            total + max(item.frame.width, 24)
        }
        return min(max(itemWidths + 20, 56), 760)
    }
}

private struct MenuBarItemButton: View {
    let item: MenuBarItemDescriptor
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: iconWidth, height: item.snapshot == nil ? 22 : item.frame.height)
                .frame(width: max(item.frame.width, 24), height: max(item.frame.height, 30) + 4)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.09) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .help(item.displayName)
        .onHover { isHovering = $0 }
    }

    private var iconWidth: CGFloat {
        item.snapshot == nil ? 22 : item.frame.width
    }
}
