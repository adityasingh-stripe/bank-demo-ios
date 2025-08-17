import SwiftUI

struct AppSettingsView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(\.viewControllerPresenter) var viewControllerPresenter

    // App info is sometimes nil, if for example it fails to load.
    var appInfo: AppInfo?

    @State private var currentMerchantId: String = ""
    @State var serverURLString: String = AppSettings.shared.selectedServerBaseURL
    @State var onboardingSettings = AppSettings.shared.onboardingSettings
    @State var presentationSettings = AppSettings.shared.presentationSettings

    var isCustomEndpointValid: Bool {
        URL(string: serverURLString)?.isValid == true
    }

    // Merchant ID is read-only, always valid
    var isMerchantIdValid: Bool {
        true
    }

    func isMerchantIdValid(_ id: String) -> Bool {
        id.starts(with: "acct_") && id.count > 5
    }

    var saveEnabled: Bool {
        isCustomEndpointValid &&
        AppSettings.shared.selectedServerBaseURL != serverURLString
    }

    init(appInfo: AppInfo?) {
        self.appInfo = appInfo
        self.currentMerchantId = AppDataManager.shared.currentAccountId ?? "Not created yet"
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Merchant Account ID")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(currentMerchantId)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        if currentMerchantId != "Not created yet" {
                            Button("Copy") {
                                UIPasteboard.general.string = currentMerchantId
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Current Account")
                } footer: {
                    Text("This account ID is created when you select a profile and complete onboarding.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section {
                                    NavigationLink {
                    OnboardingSettingsView(onboardingSettings: $onboardingSettings)
                } label: {
                    Text("Account onboarding")
                        .font(.body)
                        .foregroundColor(.primary)
                    }

                NavigationLink {
                    PresentationSettingsView(presentationSettings: $presentationSettings)
                } label: {
                    Text("View Controller Options")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                } header: {
                    Text("Component Settings")
                }

                Section {
                    TextInput(label: "", placeholder: "https://example.com", text: $serverURLString, isValid: isCustomEndpointValid)
                    Button {
                        serverURLString = AppSettings.Constants.defaultServerBaseURL
                    } label: {
                        Text("Reset to default")
                            .disabled(AppSettings.Constants.defaultServerBaseURL == serverURLString)
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("API Server Settings")
                }
            }
            .listStyle(.insetGrouped)
            .animation(.easeOut(duration: 0.2), value: currentMerchantId)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        AppSettings.shared.selectedServerBaseURL = serverURLString
                        viewControllerPresenter?.setRootViewController(AppStartViewController())
                    } label: {
                        Text("Save")
                    }
                    .disabled(!saveEnabled)
                }
            }
        }
        .environment(\.horizontalSizeClass, .compact)
    }
}
