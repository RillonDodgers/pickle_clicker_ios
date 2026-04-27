import SwiftUI

struct HiddenAppActions {
    var openApp: (HiddenAppDestination) -> Void = { _ in }
    var close: () -> Void = {}
}

private struct HiddenAppActionsKey: EnvironmentKey {
    static let defaultValue = HiddenAppActions()
}

extension EnvironmentValues {
    var hiddenAppActions: HiddenAppActions {
        get { self[HiddenAppActionsKey.self] }
        set { self[HiddenAppActionsKey.self] = newValue }
    }
}

enum NativeAppTheme {
    static let background = Color(hex: 0x0E1116)
    static let chrome = Color(hex: 0x374A67)
    static let surface = Color(hex: 0x616283).opacity(0.22)
    static let elevatedSurface = Color(hex: 0x374A67).opacity(0.58)
    static let secondaryBackground = Color(hex: 0x374A67).opacity(0.34)
    static let divider = Color(hex: 0x616283).opacity(0.5)
    static let tint = Color(hex: 0xCB9CF2)
    static let secondaryTint = Color(hex: 0x9E7B9B)
    static let secondaryText = Color(hex: 0xC3BCD7)
    static let tertiaryText = Color(hex: 0x8D8AA9)
    static let cardShadow = Color.black.opacity(0.35)
    static let success = Color(red: 0.56, green: 0.85, blue: 0.75)
}

struct NativeAppScreenContainer<Content: View>: View {
    let title: String
    let currentApp: HiddenAppDestination
    @ViewBuilder let content: Content

    @Environment(\.hiddenAppActions) private var actions

    var body: some View {
        ZStack {
            NativeAppBackdrop()

            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close", action: actions.close)
                    .foregroundStyle(NativeAppTheme.tint)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(HiddenAppDestination.allCases, id: \.rawValue) { destination in
                        Button(destination.title) {
                            actions.openApp(destination)
                        }
                        .disabled(destination == currentApp)
                    }
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .foregroundStyle(NativeAppTheme.tint)
                }
            }
        }
        .toolbarBackground(NativeAppTheme.background.opacity(0.92), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background(NativeAppTheme.background.ignoresSafeArea())
    }
}

struct NativeConfigurationRequiredView: View {
    let title: String
    let systemImage: String
    let description: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .overlay(alignment: .bottom) {
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 28)
        }
    }
}

struct NativeErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color(red: 1.0, green: 0.67, blue: 0.71))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NativeAppTheme.secondaryTint.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NativeAppTheme.secondaryTint.opacity(0.45), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
    }
}

struct NativeCompactSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(NativeAppTheme.secondaryText)
            .tracking(0.6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

struct NativeEdgeDivider: View {
    var body: some View {
        Rectangle()
            .fill(NativeAppTheme.divider)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

struct NativeEdgeRow<Content: View>: View {
    var compactVerticalPadding: CGFloat = 10
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, compactVerticalPadding)
            NativeEdgeDivider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NativeAppTheme.background)
    }
}

struct NativeSkeletonBlock: View {
    let width: CGFloat?
    let height: CGFloat
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.tertiarySystemFill))
            .frame(width: width, height: height)
            .redacted(reason: .placeholder)
    }
}

struct NativeSectionCardSkeleton: View {
    let titleWidth: CGFloat
    let rowCount: Int

    var body: some View {
        NativeEdgeRow(compactVerticalPadding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                NativeSkeletonBlock(width: titleWidth, height: 16)
                ForEach(0 ..< rowCount, id: \.self) { _ in
                    NativeSkeletonBlock(width: nil, height: 14)
                }
            }
        }
    }
}

struct NativeAppBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                NativeAppTheme.background,
                NativeAppTheme.background,
                NativeAppTheme.chrome.opacity(0.22)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            RadialGradient(
                colors: [
                    NativeAppTheme.secondaryTint.opacity(0.22),
                    NativeAppTheme.chrome.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .frame(height: 320)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

struct NativeInsetSurface<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NativeAppTheme.elevatedSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: NativeAppTheme.cardShadow, radius: 18, x: 0, y: 12)
    }
}

struct NativePill: View {
    let title: String
    var fill: Color = NativeAppTheme.secondaryTint.opacity(0.22)
    var foreground: Color = NativeAppTheme.tint

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .overlay(
                Capsule()
                    .stroke(foreground.opacity(0.18), lineWidth: 1)
            )
    }
}

struct NativeSearchField: View {
    let title: String
    @Binding var text: String
    var prompt: String

    var body: some View {
        NativeInsetSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NativeAppTheme.secondaryText)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(NativeAppTheme.secondaryTint)

                    TextField(prompt, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(NativeAppTheme.background.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NativeAppTheme.divider, lineWidth: 1)
                )
            }
        }
    }
}

struct NativeFloatingToolbar<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        NativeInsetSurface(padding: 12) {
            content
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

private extension Color {
    init(hex: UInt64, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
