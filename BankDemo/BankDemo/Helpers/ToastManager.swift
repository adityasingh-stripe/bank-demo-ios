import SwiftUI
import UIKit
import OSLog

// MARK: - Toast Message Model

struct ToastMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let message: String
    let createdAt = Date()
}

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared: ToastManager = {
        let instance = ToastManager()
        return instance
    }()
    
    // MARK: - Properties
    
    @Published var toasts: [ToastMessage] = []
    private let displayDuration: TimeInterval = 5.0
    private var toastWindow: UIWindow?
    
    // MARK: - Logging
    
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BankDemo",
        category: "ToastManager"
    )
    
    // MARK: - Initialization
    
    private init() {
        logger.info("ToastManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Shows a toast message to the user
    /// - Parameter message: The message to display
    func show(_ message: String) {
        logger.info("Showing toast: \(message)")
        
        setupWindowIfNeeded()
        let toast = ToastMessage(message: message)
        
        toasts.append(toast)
        
        // Use structured concurrency for auto-removal
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(displayDuration))
                await removeToast(toast)
            } catch {
                logger.error("Failed to schedule toast removal: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWindowIfNeeded() {
        guard toastWindow == nil else { return }
        
        do {
            let window = try createToastWindow()
            let rootVC = createRootViewController()
            
            window.rootViewController = rootVC
            window.isHidden = false
            toastWindow = window
            
            logger.debug("Toast window setup completed")
        } catch {
            logger.error("Failed to setup toast window: \(error)")
        }
    }
    
    private func createToastWindow() throws -> UIWindow {
        let window = UIWindow()
        window.backgroundColor = .clear
        window.windowLevel = .alert + 1
        window.isUserInteractionEnabled = false
        window.accessibilityIdentifier = "ToastWindow"
        
        // Find active window scene
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            throw ToastError.noActiveWindowScene
        }
        
        window.windowScene = windowScene
        return window
    }
    
    private func createRootViewController() -> UIViewController {
        let rootVC = UIHostingController(
            rootView: ToastContainerView().environmentObject(self)
        )
        rootVC.view.backgroundColor = .clear
        rootVC.view.isAccessibilityElement = true
        return rootVC
    }
    
    private func removeToast(_ toast: ToastMessage) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let index = toasts.firstIndex(of: toast) {
                toasts.remove(at: index)
                logger.debug("Toast removed: \(toast.message)")
            }
        }
        
        // Clean up window if no toasts remaining
        if toasts.isEmpty {
            cleanupWindow()
        }
    }
    
    private func cleanupWindow() {
        toastWindow?.isHidden = true
        toastWindow = nil
        logger.debug("Toast window cleaned up")
    }
}

// MARK: - Toast Errors

enum ToastError: LocalizedError {
    case noActiveWindowScene
    
    var errorDescription: String? {
        switch self {
        case .noActiveWindowScene:
            return "No active window scene available for toast display"
        }
    }
}

// MARK: - Toast Container View

struct ToastContainerView: View {
    @EnvironmentObject var toastManager: ToastManager
    
    var body: some View {
        VStack {
            Spacer()
            
            ForEach(toastManager.toasts) { toast in
                ToastView(message: toast.message)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.8))
                    ))
            }
            .padding(.bottom, 50)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toastManager.toasts)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .background(Color.black.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .accessibilityIdentifier(message)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
            .accessibilityAddTraits(.isStaticText)
    }
}
