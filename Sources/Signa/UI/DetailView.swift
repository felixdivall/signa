import SignaCore
import SwiftUI

/// Everything about one application: the preview, Apply, and keeping it.
struct DetailView: View {
    let model: LibraryViewModel
    let app: ManagedApp
    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 26)

            PreviewStage(model: model, app: app, isDropTargeted: isDropTargeted)
                .padding(.bottom, 24)

            if let attention {
                attention.padding(.bottom, 18)
            }

            applyRow
                .padding(.bottom, 22)

            keepRow

            Spacer(minLength: 18)

            footer
        }
        .padding(.horizontal, 36)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy(duration: 0.3), value: app)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name)
                    .font(.system(size: 30, weight: .semibold))
                    .lineLimit(1)
                Text(displayPath)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(app.applicationPath)
            }
            Spacer(minLength: 12)
            StatusLabel(status: app.status, prominent: true)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.6), in: Capsule())
        }
    }

    private var displayPath: String {
        (app.applicationPath as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - Things that need the user

    private var attention: AttentionCard? {
        switch app.status {
        case .needsPermission:
            AttentionCard(
                symbol: "lock.shield",
                title: "Signa needs your permission",
                message: "Turn on Signa under App Management in System Settings, then try again.",
                primary: ("Open Settings", { model.openPermissionSettings() }),
                secondary: ("Try Again", { model.apply(app) }))
        case .needsPassword:
            AttentionCard(
                symbol: "lock",
                title: "Your password is needed",
                message:
                    "\(app.name) was updated. It is installed for everyone on this Mac, so macOS asks for an administrator password before its icon can change.",
                primary: ("Put Icon Back", { model.apply(app) }),
                secondary: nil)
        case .missing:
            AttentionCard(
                symbol: "questionmark.app.dashed",
                title: "\(app.name) isn't here anymore",
                message: "If it comes back to the same place, Signa picks up where it left off.",
                primary: nil, secondary: nil)
        default:
            nil
        }
    }

    // MARK: - Apply

    @ViewBuilder private var applyRow: some View {
        switch app.status {
        case .readyToApply:
            Button {
                model.apply(app)
            } label: {
                Text("Apply")
                    .font(.headline)
                    .frame(width: 180)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(model.isBusy(app))
        case .needsIcon:
            Text("Drop an image, or click the middle tile to choose one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(height: 34)
        case .protected, .unprotected:
            VStack(spacing: 6) {
                Label(appliedCaption, systemImage: "checkmark")
                if model.awaitsRelaunch(app) {
                    // Information, not a problem: the icon is on, the Dock just has not caught up.
                    Text(
                        "\(app.name) is currently running. macOS usually shows the new icon in the Dock the next time it is launched."
                    )
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 440)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(minHeight: 34)
        case .needsPermission, .needsPassword, .missing:
            EmptyView()
        }
    }

    private var appliedCaption: String {
        guard app.enabled, let restored = app.lastRestored else {
            return model.awaitsRelaunch(app) ? "Icon applied successfully" : "Icon applied"
        }
        let when = restored.formatted(.relative(presentation: .named))
        return "Icon applied · last put back \(when)"
    }

    // MARK: - Keep after updates

    private var keepRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Keep after updates")
                    .font(.headline)
                Text(keepCaption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle(
                "Keep after updates",
                isOn: Binding(
                    get: { app.enabled },
                    set: { model.setKeepAfterUpdates($0, for: app) })
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.large)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var keepCaption: String {
        guard app.enabled else { return "The next update to \(app.name) will bring its own icon back." }
        // Honest about the one case Signa cannot handle silently.
        return model.needsAdministrator(app)
            ? "After an update, Signa asks for your password before putting this icon back."
            : "Signa puts this icon back whenever \(app.name) is updated."
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 18) {
            Button("Restore Original Icon") { model.restoreOriginal(app) }
                .disabled(app.customIcon == nil || model.isBusy(app))
            Button("Show in Finder") { model.showInFinder(app) }
                .disabled(app.status == .missing)
            Spacer()
            Button("Forget…") { model.forgetCandidate = app }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }
}

/// A calm explanation of something only the user can fix.
private struct AttentionCard: View {
    let symbol: String
    let title: String
    let message: String
    let primary: (title: String, action: () -> Void)?
    let secondary: (title: String, action: () -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if primary != nil || secondary != nil {
                    HStack(spacing: 8) {
                        if let primary { Button(primary.title, action: primary.action) }
                        if let secondary { Button(secondary.title, action: secondary.action) }
                    }
                    .padding(.top, 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
