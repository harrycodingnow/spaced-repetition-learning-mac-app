import SwiftUI

enum LiquidTheme {
    static let accent = Color(red: 0.28, green: 0.95, blue: 0.58)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)
}

struct LiquidBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.018, blue: 0.024)

            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.12, blue: 0.11).opacity(0.72),
                    Color.black.opacity(0.18),
                    Color(red: 0.03, green: 0.05, blue: 0.10).opacity(0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(LiquidTheme.accent.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: -230, y: -145)

            Circle()
                .fill(Color.cyan.opacity(0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 95)
                .offset(x: 250, y: 170)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                Glass.regular.tint(tint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill((tint ?? .white).opacity(tint == nil ? 0.025 : 0.06))
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct LiquidContentSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background(.ultraThinMaterial, in: shape)
            .overlay {
                shape
                    .fill((tint ?? .white).opacity(tint == nil ? 0.028 : 0.055))
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.055),
                                Color.white.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.22), radius: 10, y: 5)
    }
}

extension View {
    func liquidGlassSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                tint: tint,
                interactive: interactive
            )
        )
    }

    func liquidContentSurface(
        cornerRadius: CGFloat,
        tint: Color? = nil
    ) -> some View {
        modifier(LiquidContentSurfaceModifier(cornerRadius: cornerRadius, tint: tint))
    }

    @ViewBuilder
    func liquidButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                self
                    .buttonStyle(.glass)
                    .tint(tint)
            }
        } else if prominent {
            self
                .buttonStyle(.borderedProminent)
                .tint(tint)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

struct SectionCard<HeaderAccessory: View, Content: View>: View {
    let title: String
    let systemImage: String
    let usesLiquidGlass: Bool
    let showsBackground: Bool
    let headerAccessory: HeaderAccessory
    let content: Content

    init(
        _ title: String,
        systemImage: String,
        usesLiquidGlass: Bool = false,
        showsBackground: Bool = true,
        @ViewBuilder content: () -> Content
    ) where HeaderAccessory == EmptyView {
        self.title = title
        self.systemImage = systemImage
        self.usesLiquidGlass = usesLiquidGlass
        self.showsBackground = showsBackground
        self.headerAccessory = EmptyView()
        self.content = content()
    }

    init(
        _ title: String,
        systemImage: String,
        usesLiquidGlass: Bool = false,
        showsBackground: Bool = true,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.usesLiquidGlass = usesLiquidGlass
        self.showsBackground = showsBackground
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        Group {
            if !showsBackground {
                cardContent
            } else if usesLiquidGlass {
                cardContent
                    .liquidGlassSurface(
                        cornerRadius: 18,
                        tint: LiquidTheme.accent.opacity(0.035)
                    )
            } else {
                cardContent
                    .liquidContentSurface(cornerRadius: 18)
            }
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(LiquidTheme.accent)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(LiquidTheme.accent.opacity(0.12))
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer(minLength: 6)

                headerAccessory
            }

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StudyRoutePicker: View {
    @EnvironmentObject private var store: SRLDataStore

    var body: some View {
        Picker("Question route", selection: $store.selectedStudyRoute) {
            ForEach(StudyRoute.allCases) { studyRoute in
                Text(studyRoute.displayName)
                    .tag(studyRoute)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.mini)
        .fixedSize()
        .help("Choose the question route")
        .accessibilityLabel("Question route")
        .accessibilityValue(store.selectedStudyRoute.displayName)
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    let color: Color
    var isSelected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(LiquidTheme.secondaryText)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidContentSurface(cornerRadius: 16, tint: color)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? color.opacity(0.82) : Color.clear,
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ExternalLinkButton: View {
    let urlString: String?

    var body: some View {
        if let urlString, let url = URL(string: urlString) {
            Link(destination: url) {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption.weight(.medium))
                    .frame(width: 18, height: 18)
            }
            .foregroundColor(LiquidTheme.secondaryText)
            .liquidButtonStyle()
            .controlSize(.mini)
            .help("Open problem")
        }
    }
}
