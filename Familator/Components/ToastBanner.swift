import SwiftUI

// MARK: - Data Types

enum ToastVariant: Equatable {
    case error
    case success

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .error: return .errorForeground
        case .success: return .successForeground
        }
    }
}

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let variant: ToastVariant
    let message: String
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    @Published var current: ToastItem?

    private var dismissTask: Task<Void, Never>?

    func show(_ variant: ToastVariant, message: String, duration: TimeInterval = 3.0) {
        dismissTask?.cancel()
        current = ToastItem(variant: variant, message: message)
        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return // cancelled — don't clear
            }
            self?.current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

// MARK: - Toast Banner View

struct ToastBanner: View {
    let item: ToastItem
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.variant.icon)
                .foregroundColor(item.variant.iconColor)

            Text(item.message)
                .font(.toastBody)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.toastBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .toastShadow, radius: 8, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - View Modifier

struct ToastModifier: ViewModifier {
    @ObservedObject var manager: ToastManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let item = manager.current {
                ToastBanner(item: item, onDismiss: { manager.dismiss() })
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.4), value: manager.current?.id)
    }
}

extension View {
    func toast(manager: ToastManager) -> some View {
        modifier(ToastModifier(manager: manager))
    }
}
