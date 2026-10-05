import SwiftUI

/// The first thing a new user sees: one sentence and one place to drop an app.
struct WelcomeView: View {
    let model: LibraryViewModel
    let isDropTargeted: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(
                        isDropTargeted ? Color.accentColor : Color.primary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 2, dash: isDropTargeted ? [] : [7, 7]))
                Image(systemName: isDropTargeted ? "arrow.down" : "plus")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 148, height: 148)
            .scaleEffect(isDropTargeted ? 1.06 : 1)
            .padding(.bottom, 34)

            Text("Drop an app to begin")
                .font(.system(size: 30, weight: .semibold))
                .padding(.bottom, 10)

            Text("Give it the icon you want. Signa keeps it there,\neven when an update tries to change it back.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.bottom, 28)

            Button("Choose an App…") { model.chooseApplication() }
                .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
