import SwiftUI
import UIKit

/// Setup the first time, then the four tabs.
struct RootView: View {
    let model: AppModel

    @AppStorage("setupDone") private var setupDone = false
    @AppStorage("appearance") private var appearance = "system"

    private var showsSetup: Bool {
        if let demo = model.demoScreen, demo.hasPrefix("setup") { return true }
        return !setupDone
    }

    var body: some View {
        Group {
            if showsSetup {
                SetupFlow(model: model) { setupDone = true }
            } else {
                MainView(model: model)
            }
        }
        .tint(Theme.blue)
        .task { await model.keepInTouch() }
        .onAppear { Self.apply(appearance) }
        .onChange(of: appearance) { _, chosen in Self.apply(chosen) }
    }

    /// Light, dark, or whatever the iPhone is set to. Set on the window, so sheets follow.
    static func apply(_ appearance: String) {
        let style: UIUserInterfaceStyle = appearance == "light" ? .light : appearance == "dark" ? .dark : .unspecified
        for scene in UIApplication.shared.connectedScenes {
            (scene as? UIWindowScene)?.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}

/// The four tabs under a floating tab bar, and every sheet that can rise over them.
struct MainView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            switch model.tab {
            case .now: NowScreen(model: model)
            case .people: PeopleTab(model: model)
            case .recaps: RecapScreen(model: model)
            case .privacy: PrivacyTabScreen(model: model)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            TabBar(selection: $model.tab)
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $model.sheet) { sheet in
            switch sheet {
            case .settings:
                SettingsScreen(model: model)
            case .device(let device):
                NavigationStack { DeviceScreen(model: model, device: device, backLabel: nil) }
            case .register(let name):
                RegisterView(model: model, presetName: name ?? "")
            case .showSomeone:
                ShowSomeoneScreen(model: model)
            case .recognized(let name):
                RecognizedScreen(model: model, name: name)
            case .possible(let name):
                PossibleMatchScreen(model: model, name: name)
            }
        }
    }
}

/// One of the four set-up-once screens, opened from Settings or from the Now tab.
struct DeviceScreen: View {
    let model: AppModel
    let device: AppModel.Device
    /// The screen to go back to, or nil when this is a sheet of its own.
    let backLabel: String?

    var body: some View {
        switch device {
        case .server: ConnectScreen(model: model, backLabel: backLabel)
        case .band: PairScreen(model: model, backLabel: backLabel)
        case .camera: CameraScreen(model: model, backLabel: backLabel)
        case .voice: VoiceScreen(model: model, backLabel: backLabel)
        }
    }
}

/// Welcome, then the five steps: server, band, privacy, camera, voice.
struct SetupFlow: View {
    enum Step: Hashable { case server, band, privacy, camera, voice }

    let model: AppModel
    let finish: () -> Void

    @State private var path: [Step] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen {
                // A phone already talking to its server goes straight to the band.
                path.append(model.faces.state == .live ? .band : .server)
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .server: ConnectScreen(model: model, next: { path.append(.band) })
                case .band: PairScreen(model: model, next: { path.append(.privacy) })
                case .privacy: SetupPrivacyScreen(model: model, next: { path.append(.camera) })
                case .camera: CameraScreen(model: model, next: { path.append(.voice) })
                case .voice: VoiceScreen(model: model, next: finish)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 130)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            switch model.demoScreen {
            case "setup-server": path = [.server]
            case "setup-band": path = [.band]
            case "setup-privacy": path = [.privacy]
            case "setup-camera": path = [.camera]
            case "setup-voice": path = [.voice]
            default: break
            }
        }
    }
}

/// The top of a set-up-once screen: the setup steps, a way back, or Done on a sheet.
struct StepHeader: View {
    let step: Int
    let inSetup: Bool
    let backLabel: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if inSetup {
            SetupHeader(step: step) { dismiss() }
        } else if let backLabel {
            BackLink(label: backLabel) { dismiss() }
        } else {
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.blue)
                    .frame(height: 44)
            }
            .padding(.top, 8)
        }
    }
}
