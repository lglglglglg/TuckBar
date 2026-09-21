import SwiftUI

private enum PreferencesPage: String, CaseIterable, Identifiable {
    case general
    case guide
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "通用设置"
        case .guide: "使用教程"
        case .about: "帮助与关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .guide: "play.rectangle.fill"
        case .about: "info.circle.fill"
        }
    }
}


struct SettingsView: View {
    @ObservedObject var model: AppModel
    let refreshItems: () -> Void
    let applyHiddenItems: () -> Void
    let revealAllItems: () -> Void
    let showAggregatePanel: () -> Void
    let requestScreenRecordingPermission: () -> Void
    let requestAccessibilityPermission: () -> Void
    let quit: () -> Void
    @State private var selectedPage: PreferencesPage = .general
    @State private var isTipJarPresented = false
    @State private var isLicensePresented = false
    @State private var isPrivacyPresented = false
    @State private var showCopiedFeedback = false
    @State private var copiedMessage = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 185)

            ScrollView {
                pageContent
                    .padding(.horizontal, 28)
                    .padding(.top, 32)
                    .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black.opacity(0.10))
        }
        .frame(width: 860, height: 620)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.21, blue: 0.50),
                    Color(red: 0.14, green: 0.44, blue: 0.48),
                    Color(red: 0.30, green: 0.17, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if showCopiedFeedback {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(copiedMessage)
                        .font(.callout.weight(.medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .padding(.top, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $isTipJarPresented) {
            TipJarView(isPresented: $isTipJarPresented)
        }
        .sheet(isPresented: $isLicensePresented) {
            LicenseSheetView(isPresented: $isLicensePresented)
        }
        .sheet(isPresented: $isPrivacyPresented) {
            PrivacySheetView(isPresented: $isPrivacyPresented)
        }
        .preferredColorScheme(.dark)
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(nsImage: brandIcon)
                    .resizable()
                    .frame(width: 68, height: 68)
                Text(Brand.name)
                    .font(.headline)
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(.top, 42)
            .padding(.bottom, 26)

            VStack(spacing: 5) {
                ForEach(PreferencesPage.allCases) { page in
                    SidebarButton(
                        title: page.title,
                        symbol: page.symbol,
                        isSelected: selectedPage == page
                    ) {
                        selectedPage = page
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            Button(action: quit) {
                Label("退出应用", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))
            .padding(12)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.12))
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .general:
            generalPage
        case .guide:
            guidePage
        case .about:
            aboutPage
        }
    }

    private var brandIcon: NSImage {
        guard let url = Bundle.main.url(forResource: "TuckBarBrand", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else { return Brand.image(size: 136, colored: true) }
        return image
    }

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            PageTitle(symbol: "rocket.fill", title: "启动与常规")

            SettingsCard {
                Toggle("登录时自动启动 TuckBar", isOn: $model.launchAtLogin)
            }

            PageTitle(symbol: "slider.horizontal.3", title: "显示与交互")

            SettingsCard {
                Text("收纳显示模式").font(.headline)
                Picker("收纳显示模式", selection: $model.displayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.displayMode.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))

                Divider().overlay(.white.opacity(0.14))

                Text("菜单栏图标样式").font(.headline)
                Picker("菜单栏图标样式", selection: $model.iconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Divider().overlay(.white.opacity(0.14))

                Toggle("鼠标悬停在 TuckBar 图标时自动展开", isOn: $model.openOnHover)

                Toggle("在菜单栏区域滑动滚轮/双指手势展开或收起", isOn: $model.triggerOnScroll)

                Toggle(isOn: $model.enableGlobalHotkey) {
                    HStack {
                        Text("启用全局快捷键展开/收起")
                        Spacer()
                        Text("⌥ B")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                    }
                }

                if model.displayMode == .menuBar {
                    Divider().overlay(.white.opacity(0.14))
                    HStack {
                        Text("展开后自动收起延时")
                        Spacer()
                        Picker("", selection: $model.autoCollapseDelay) {
                            Text("5 秒").tag(5.0)
                            Text("8 秒").tag(8.0)
                            Text("15 秒").tag(15.0)
                            Text("手动点击（不自动收起）").tag(0.0)
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }
                    .font(.callout)
                }
            }

            PageTitle(symbol: "key.fill", title: "系统授权")

            SettingsCard {
                PermissionRow(
                    title: "辅助功能",
                    detail: "用于移动、隐藏和点击真实菜单栏项目",
                    isGranted: model.hasAccessibilityPermission,
                    grant: requestAccessibilityPermission
                )
                Divider().overlay(.white.opacity(0.14))
                PermissionRow(
                    title: "屏幕录制",
                    detail: "用于读取菜单栏项目位置和原始图标，不保存桌面录像",
                    isGranted: model.hasScreenRecordingPermission,
                    grant: requestScreenRecordingPermission
                )
            }

            if !model.hasAccessibilityPermission || !model.hasScreenRecordingPermission {
                SettingsCard {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("部分权限尚未授予，请在上方完成授权以确保收纳正常运行。")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
    }

    private var guidePage: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageTitle(symbol: "play.rectangle.fill", title: "使用教程与技巧")
            SettingsCard {
                GuideRow(number: "1", title: "系统授权", detail: "首次使用需授予“辅助功能”以操作原生图标，授予“屏幕录制”以高清渲染原始菜单栏图标。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "2", title: "按需展开 / 收起", detail: "左键点击 TuckBar 图标、或悬停、或在菜单栏区域滑动滚轮/触控板双指，即可流畅展开或收起隐藏图标。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "3", title: "全局快捷键 ⌥ B", detail: "在任何应用全屏或专注状态下，直接按下 Option + B（⌥ B）即可瞬间呼出菜单栏收纳。")
                Divider().overlay(.white.opacity(0.14))
                GuideRow(number: "4", title: "快捷菜单与重新扫描", detail: "右键 TuckBar 图标可唤出快捷功能菜单，随时进行重新扫描、收起或暂时展开全部。")
            }
        }
    }

    private var appVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.9.7"
    }

    private var appBuildString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "36"
    }

    private var diagnosticInfo: String {
        """
        [TuckBar 诊断信息]
        版本: \(appVersionString) (构建号 \(appBuildString))
        系统版本: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        设备架构: \(ProcessInfo.processInfo.activeProcessorCount) 核 / \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)) GB 内存
        屏幕录制权限: \(model.hasScreenRecordingPermission ? "已授予" : "未授予")
        辅助功能权限: \(model.hasAccessibilityPermission ? "已授予" : "未授予")
        显示模式: \(model.displayMode.title)
        """
    }

    private func copyToClipboard(_ text: String, message: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copiedMessage = message
        withAnimation(.spring()) {
            showCopiedFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut) {
                showCopiedFeedback = false
            }
        }
    }

    private var aboutPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            // 顶部大标题与副标题
            VStack(alignment: .leading, spacing: 4) {
                Text("关于")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("版本信息、更新与反馈")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }

            // 软件品牌 Header 卡片
            HStack(spacing: 18) {
                Image(nsImage: brandIcon)
                    .resizable()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(Brand.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("让 Mac 菜单栏更整洁优雅")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.72))

                    Text("Alpha 内测版")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.14), in: Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding(18)
            .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))

            // 1. 版本
            SettingsCard {
                SectionHeader(symbol: "shippingbox.fill", title: "版本")

                ActionRow(
                    title: "当前版本",
                    detail: "版本 \(appVersionString) · 构建 \(appBuildString)"
                ) {
                    Button("检查更新") {
                        if let url = URL(string: "https://github.com/lglglglglg/TuckBar/releases") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Divider().overlay(.white.opacity(0.12))

                ActionRow(
                    title: "诊断信息",
                    detail: "反馈问题时附上版本与系统信息"
                ) {
                    Button("复制") {
                        copyToClipboard(diagnosticInfo, message: "诊断信息已复制到剪贴板")
                    }
                }
            }

            // 2. 开源与支持
            SettingsCard {
                SectionHeader(symbol: "chevron.left.forwardslash.chevron.right", title: "开源与支持")

                ActionRow(
                    title: "开源仓库",
                    detail: "浏览源码、更新记录并参与开发"
                ) {
                    Button("打开 GitHub") {
                        if let url = URL(string: "https://github.com/lglglglglg/TuckBar") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Divider().overlay(.white.opacity(0.12))

                ActionRow(
                    title: "支持项目",
                    detail: "微信或支付宝自愿赞赏，支持持续开发"
                ) {
                    Button("查看赞赏页") {
                        isTipJarPresented = true
                    }
                }
            }

            // 3. 帮助与反馈
            SettingsCard {
                SectionHeader(symbol: "bubble.left.and.bubble.right.fill", title: "帮助与反馈")

                ActionRow(
                    title: "反馈与建议",
                    detail: "提交 Issue 或功能改进建议"
                ) {
                    Button("提交反馈") {
                        if let url = URL(string: "https://github.com/lglglglglg/TuckBar/issues/new") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Divider().overlay(.white.opacity(0.12))

                ActionRow(
                    title: "反馈模板",
                    detail: "复制版本与系统信息，便于定位问题"
                ) {
                    Button("复制模板") {
                        let template = """
                        ### 问题描述
                        请在此简要描述您遇到的问题或期望的行为：

                        ### 复现步骤
                        1. 
                        2. 
                        3. 

                        ### 环境信息
                        \(diagnosticInfo)
                        """
                        copyToClipboard(template, message: "反馈模板已复制到剪贴板")
                    }
                }

                Divider().overlay(.white.opacity(0.12))

                ActionRow(
                    title: "开源协议",
                    detail: "查看 TuckBar 的 MIT License"
                ) {
                    Button("查看") {
                        isLicensePresented = true
                    }
                }

                Divider().overlay(.white.opacity(0.12))

                ActionRow(
                    title: "隐私政策",
                    detail: "本地数据、系统权限与第三方请求说明"
                ) {
                    Button("查看") {
                        isPrivacyPresented = true
                    }
                }
            }

            // 4. 创作与版权
            SettingsCard {
                SectionHeader(symbol: "person.badge.shield.checkmark.fill", title: "创作与版权")

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("工作室")
                        Text("项目创作与维护")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text("韩十久工作室（Hanshijiu Studio）")
                        .foregroundStyle(.white.opacity(0.85))
                }

                Divider().overlay(.white.opacity(0.12))

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("主理人")
                        Text("产品与开源维护")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Link(destination: URL(string: "https://github.com/lglglglglg")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Stephan Li")
                        }
                    }
                }

                Divider().overlay(.white.opacity(0.12))

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("版权所有")
                        Text("© 2026 Stephan Li（韩十久工作室 · Hanshijiu Studio）")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Text("MIT License")
                        .foregroundStyle(.white.opacity(0.85))
                }

                Divider().overlay(.white.opacity(0.12))

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("联系邮箱")
                        Text("项目反馈与公开联系邮箱")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Link("lixiaolongstephan@gmail.com", destination: URL(string: "mailto:lixiaolongstephan@gmail.com")!)
                }
            }

            // 底部注脚
            Text("问题与建议会在 GitHub Issues 中公开跟进；提交前请勿包含访问令牌、私人日历或其他敏感信息。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.50))
                .padding(.horizontal, 4)
                .padding(.bottom, 12)
        }
    }
}

private struct SidebarButton: View {
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .background(
                    isSelected ? .white.opacity(0.19) : .clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PageTitle: View {
    let symbol: String
    let title: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
    }
}

private struct SettingsCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

private struct ActionRow<Trailing: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            trailing
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let grant: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
            if isGranted {
                Text("已授权")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Button("去授权", action: grant)
            }
        }
    }
}

private struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.68))
        }
    }
}


private struct GuideRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline)
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
    }
}

private struct SectionHeader: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.bottom, 2)
    }
}

// MARK: - 赞赏弹窗 (Tip Jar View)
private struct TipJarView: View {
    @Binding var isPresented: Bool
    @State private var paymentMethod: PaymentMethod = .wechat

    enum PaymentMethod: String, CaseIterable, Identifiable {
        case wechat = "微信支付"
        case alipay = "支付宝"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("支持 TuckBar 开发")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("您的自愿赞赏是独立开源项目持续迭代与维护的最大动力！")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.70))
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Picker("", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 280, height: 280)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)

                if paymentMethod == .wechat {
                    if let img = qrImage(named: "WeChatPay") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 260, height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("微信收款码加载中…")
                            .foregroundStyle(.black)
                    }
                } else {
                    if let img = qrImage(named: "AliPay") {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 260, height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("支付宝收款码加载中…")
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(.vertical, 8)

            Text("扫描上方二维码向创作者（Stephan Li · 韩十久工作室）赞赏，万分感谢！❤️")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)

            Button("完成") {
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(width: 440, height: 500)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.16, blue: 0.38),
                    Color(red: 0.12, green: 0.28, blue: 0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private func qrImage(named name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // Fallback to Resources relative path if running in dev/preview
        let fallbackPath = "Resources/\(name).jpg"
        return NSImage(contentsOfFile: fallbackPath)
    }
}

// MARK: - 开源协议弹窗 (MIT License)
private struct LicenseSheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("MIT 开源协议 (License)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                Text("""
                MIT License

                Copyright (c) 2026 Stephan Li (Hanshijiu Studio)

                Permission is hereby granted, free of charge, to any person obtaining a copy
                of this software and associated documentation files (the "Software"), to deal
                in the Software without restriction, including without limitation the rights
                to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
                copies of the Software, and to permit persons to whom the Software is
                furnished to do so, subject to the following conditions:

                The above copyright notice and this permission notice shall be included in all
                copies or substantial portions of the Software.

                THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
                IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
                FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
                AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
                LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
                OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
                SOFTWARE.
                """)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxHeight: 320)

            HStack {
                Spacer()
                Button("关闭") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
        .background {
            Color(red: 0.16, green: 0.18, blue: 0.24).ignoresSafeArea()
        }
    }
}

// MARK: - 隐私政策弹窗 (Privacy Policy)
private struct PrivacySheetView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("隐私政策与安全声明")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("1. 100% 本地运行，绝不上报数据")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("TuckBar 是一款纯原生本地工具，不包含任何网络请求、跟踪分析、遥测探针或广告 SDK。您的任何设备信息、菜单栏应用列表与个人数据均仅存储在您本机的沙盒中，永远不会被上传至外部服务器。")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))

                    Divider().overlay(.white.opacity(0.12))

                    Text("2. 辅助功能权限 (Accessibility)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("仅用于获取菜单栏原始状态项的屏幕坐标，并在您点击图标时模拟触发原生菜单栏动作。")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))

                    Divider().overlay(.white.opacity(0.12))

                    Text("3. 屏幕录制权限 (Screen Recording)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("仅用于通过 macOS 系统底层接口截取菜单栏状态项的高清矢量图标并显示在浮岛中。TuckBar 绝不会录制、截取或保存您的桌面屏幕或任何窗口内容。")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(16)
                .background(.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
            .frame(maxHeight: 320)

            HStack {
                Spacer()
                Button("了解并关闭") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 520, height: 440)
        .background {
            Color(red: 0.16, green: 0.18, blue: 0.24).ignoresSafeArea()
        }
    }
}

