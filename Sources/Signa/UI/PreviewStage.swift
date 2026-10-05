import SignaCore
import SwiftUI

/// Current → Custom → Result, large enough to judge the icon properly.
struct PreviewStage: View {
    let model: LibraryViewModel
    let app: ManagedApp
    let isDropTargeted: Bool

    private let small: CGFloat = 92
    private let large: CGFloat = 172

    /// The icon being previewed: a pending choice first, otherwise the applied one.
    private var asset: IconAsset.ID? { app.stagedIcon ?? app.customIcon }

    /// With nothing pending, the first tile shows where the app started.
    private var isSettled: Bool { app.stagedIcon == nil && app.customIcon != nil }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tile(isSettled ? "Original" : "Current") {
                IconImage(image: startingIcon, size: small)
            }
            arrow
            tile("Custom") { customTile }
            arrow
            tile("Result") { resultTile }
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.quaternary.opacity(0.35))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
        }
    }

    private var startingIcon: NSImage {
        if !isSettled, let applied = app.customIcon, let icon = model.icon(for: applied) {
            return icon
        }
        return model.originalIcon(of: app)
    }

    // MARK: - Tiles

    private func tile(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 12) {
            content()
                .frame(height: large)
            Text(title)
                .font(.caption.weight(.medium))
                .textCase(.uppercase)
                .tracking(0.9)
                .foregroundStyle(.secondary)
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 26)
    }

    /// The artwork the user chose. Also the place to drop or pick a new one.
    private var customTile: some View {
        Button {
            model.chooseImage(for: app)
        } label: {
            ZStack {
                if let asset, let artwork = model.artwork(for: asset) {
                    Image(nsImage: artwork)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: small, height: small)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .id(asset)
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            Color.primary.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary)
                }
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .padding(-5)
                    .opacity(isDropTargeted ? 1 : 0)
            }
            .frame(width: small, height: small)
            .scaleEffect(isDropTargeted ? 1.06 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Drop an image here, or click to choose one")
        .accessibilityLabel("Choose an icon image")
    }

    @ViewBuilder private var resultTile: some View {
        if let asset, let icon = model.icon(for: asset) {
            IconImage(image: icon, size: large)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .id(asset)
        } else {
            RoundedRectangle(cornerRadius: large * 0.225, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .padding(large * 0.1)
                .frame(width: large, height: large)
        }
    }
}
