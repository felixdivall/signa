import AppKit
import SignaCore
import SwiftUI

/// An icon drawn crisply at a fixed size.
struct IconImage: View {
    let image: NSImage
    let size: CGFloat

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

struct StatusLabel: View {
    let status: ManagedApp.Status
    var prominent = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.symbol)
                .foregroundStyle(status.tint)
                .imageScale(prominent ? .medium : .small)
            Text(status.title)
                .foregroundStyle(prominent ? .primary : .secondary)
        }
        .font(prominent ? .callout.weight(.medium) : .caption)
        .lineLimit(1)
    }
}

extension ManagedApp.Status {
    var title: String {
        switch self {
        case .needsIcon: "No custom icon"
        case .readyToApply: "Ready to apply"
        case .protected: "Protected"
        case .unprotected: "Unprotected"
        case .needsPermission: "Needs permission"
        case .needsPassword: "Needs your password"
        case .missing: "App not found"
        }
    }

    var symbol: String {
        switch self {
        case .needsIcon: "circle.dashed"
        case .readyToApply: "circle.fill"
        case .protected: "checkmark.shield.fill"
        case .unprotected: "shield.slash"
        case .needsPermission: "exclamationmark.triangle.fill"
        case .needsPassword: "lock.fill"
        case .missing: "questionmark.app.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .protected: .green
        case .readyToApply: .accentColor
        case .needsPermission, .needsPassword: .orange
        case .needsIcon, .unprotected, .missing: .secondary
        }
    }
}

/// The translucent material macOS uses behind sidebars.
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.material = material
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
