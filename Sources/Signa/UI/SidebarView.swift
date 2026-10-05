import SignaCore
import SwiftUI

struct SidebarView: View {
    @Bindable var model: LibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $model.selection) {
                ForEach(model.apps) { app in
                    AppRow(model: model, app: app)
                        .tag(app.id)
                        .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 8))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            footer
        }
        .background(VisualEffectBackground(material: .sidebar).ignoresSafeArea())
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                model.chooseApplication()
            } label: {
                Label("Add App", systemImage: "plus")
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 4)

            if model.protectedCount > 0 {
                Label("\(model.protectedCount) protected", systemImage: "checkmark.shield.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Signa keeps these icons in place, even while this window is closed.")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Divider() }
    }
}

/// One managed application: its own icon, its custom icon, its name and status.
private struct AppRow: View {
    let model: LibraryViewModel
    let app: ManagedApp
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 11) {
            IconPair(
                original: model.originalIcon(of: app),
                custom: (app.stagedIcon ?? app.customIcon).flatMap { model.icon(for: $0) })

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                StatusLabel(status: app.status)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-4)
                .opacity(isDropTargeted ? 1 : 0)
        )
        .help(app.applicationPath)
        .dropDestination(for: URL.self) { urls, _ in
            model.handleDrop(urls, onto: app.id)
        } isTargeted: {
            isDropTargeted = $0
        }
        .contextMenu {
            Button("Show in Finder") { model.showInFinder(app) }
            if app.customIcon != nil {
                Button("Restore Original Icon") { model.restoreOriginal(app) }
            }
            Divider()
            Button("Forget…", role: .destructive) { model.forgetCandidate = app }
        }
    }
}

/// The application's own icon tucked behind the custom one.
private struct IconPair: View {
    let original: NSImage
    let custom: NSImage?

    var body: some View {
        ZStack {
            if let custom {
                IconImage(image: original, size: 24)
                    .opacity(0.85)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                IconImage(image: custom, size: 34)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            } else {
                IconImage(image: original, size: 38)
            }
        }
        .frame(width: 46, height: 42)
    }
}
