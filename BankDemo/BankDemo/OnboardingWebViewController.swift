import UIKit
import WebKit

class OnboardingWebViewController: UIViewController {
    
    private let webView = WKWebView()
    private let url: URL
    private let accountId: String
    
    var onboardingCompleted: ((Bool) -> Void)?
    
    init(url: URL, accountId: String) {
        self.url = url
        self.accountId = accountId
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadOnboarding()
    }
    
    private func setupUI() {
        title = "Complete Setup"
        view.backgroundColor = .white
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadOnboarding() {
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    @objc private func cancelTapped() {
        onboardingCompleted?(false)
        dismiss(animated: true)
    }
}

extension OnboardingWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url {
            // Check if this is a return URL from Stripe onboarding
            if url.absoluteString.contains("return") || url.absoluteString.contains("success") {
                // Onboarding completed successfully
                onboardingCompleted?(true)
                dismiss(animated: true)
                decisionHandler(.cancel)
                return
            } else if url.absoluteString.contains("refresh") || url.absoluteString.contains("error") {
                // Onboarding failed or needs refresh
                onboardingCompleted?(false)
                dismiss(animated: true)
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Could add additional logic here if needed
    }
} 