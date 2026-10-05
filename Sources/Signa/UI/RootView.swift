import SwiftUI

struct RootView: View {
    @Bindable var model: LibraryViewModel
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if model.apps.isEmpty {
                WelcomeView(model: model, isDropTargeted: isDropTargeted)
            } else {
                HStack(spacing: 0) {
                    SidebarView(model: model)
                        .frame(width: 264)
                    Divider().ignoresSafeArea()
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 780, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .overlay(alignment: .bottom) { noticeToast }
        .overlay { dropHighlight }
        .dropDestination(for: URL.self) { urls, _ in
            model.handleDrop(urls)
        } isTargeted: { targeted in
            withAnimation(.snappy(duration: 0.2)) { isDropTargeted = targeted }
        }
        .confirmationDialog(
            "Forget \(model.forgetCandidate?.name ?? "this app")?",
            isPresented: Binding(
                get: { model.forgetCandidate != nil },
                set: { if !$0 { model.forgetCandidate = nil } }),
            presenting: model.forgetCandidate
        ) { app in
            Button("Forget", role: .destructive) { model.forget(app) }
        } message: { app in
            Text(
                app.customIcon == nil
                    ? "Signa will stop keeping track of \(app.name)."
                    : "Signa will stop looking after \(app.name). Its icon stays as it is until the next update replaces it."
            )
        }
        .animation(.snappy(duration: 0.3), value: model.apps.isEmpty)
        .animation(.snappy(duration: 0.3), value: model.notice)
    }

    @ViewBuilder private var detail: some View {
        if let app = model.selectedApp {
            DetailView(model: model, app: app, isDropTargeted: isDropTargeted)
                .id(app.id)
        } else {
            Text("Select an app")
                .font(.title3)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private var noticeToast: some View {
        if let notice = model.notice {
            Text(notice.text)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(.bottom, 22)
                .padding(.horizontal, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(notice.id)
        }
    }

    @ViewBuilder private var dropHighlight: some View {
        if isDropTargeted, !model.apps.isEmpty {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 3)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }
}
