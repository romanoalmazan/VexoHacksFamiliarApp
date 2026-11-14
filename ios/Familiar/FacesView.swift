import SwiftUI

/// The registered people, what is remembered about each, and who the camera sees now.
struct FacesView: View {
    let watch: FaceWatch

    private var faces: FaceClient { watch.faces }
    private var glasses: GlassesCamera { watch.glasses }
    private var camera: PhoneCamera { watch.phone }
    private var cameraProblem: String? { watch.phoneProblem }

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("pairingCode") private var pairingCode = ""

    @AppStorage("useGlasses") private var useGlasses = false

    @State private var registering = false

    private var isOn: Bool { watch.isOn }

    var body: some View {
        List {
            Section {
                TextField("Server, e.g. ws://my-laptop.local:8765", text: $serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .disabled(isOn)
                TextField("Pairing code", text: $pairingCode)
                    .keyboardType(.numberPad)
                    .disabled(isOn)
                Picker("Camera", selection: $useGlasses) {
                    Text("iPhone").tag(false)
                    Text("Meta glasses").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(isOn)
                if useGlasses && !glasses.isLinked && !glasses.isPretend {
                    Button(glasses.isLinking ? "Waiting for Meta AI…" : "Link Meta glasses") { Task { await glasses.link() } }
                        .disabled(glasses.isLinking)
                    Text("Opens the Meta AI app to approve Familiar. First turn on Developer Mode there: Settings → Your glasses → Developer Mode.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Toggle("Look for faces", isOn: Binding(get: { isOn }, set: { on in look(on) }))
                Toggle("Say who it is out loud", isOn: Binding(get: { faces.speaks }, set: { faces.speaks = $0 }))
                if case .failed(let reason) = faces.state {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            } footer: {
                Text("Switching Listen on does this for you. One picture a second goes to your server on this Wi-Fi. The glasses' own light is on while their camera is. It is compared with the people below and then thrown away. Nothing is kept about anyone else.")
            }

            if faces.state == .live {
                Section("In view") {
                    if useGlasses {
                        glassesPreview
                    } else if let cameraProblem {
                        Text(cameraProblem).font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        CameraPreview(session: camera.session)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(alignment: .topTrailing) {
                                Button { camera.flip() } label: {
                                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                        .padding(10)
                                        .background(.thinMaterial, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .accessibilityLabel("Switch camera")
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                    ForEach(faces.inView) { person in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.isSure ? person.name : "Possibly \(person.name)")
                                .font(.title3.weight(.semibold))
                            Text(person.isSure ? person.relationship : "Not sure enough to say out loud")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if person.isSure, let recall = person.recall, !recall.isEmpty {
                                Text(recall).font(.body).padding(.top, 2)
                            }
                        }
                    }
                    if faces.inView.isEmpty {
                        Text(faces.strangers > 0 ? "Someone who has not been added" : "Nobody in view")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if faces.people.isEmpty {
                        Text("Nobody yet").foregroundStyle(.secondary)
                    }
                    ForEach(faces.people) { person in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(person.name).font(.headline)
                                Text(person.relationship).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(person.photos ?? 0) photo\(person.photos == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let recall = person.recall, !recall.isEmpty {
                                Text(recall).font(.subheadline)
                            }
                            ForEach(person.facts ?? [], id: \.self) { fact in
                                Label(fact, systemImage: "circle.fill")
                                    .labelStyle(FactLabel())
                            }
                            ForEach(person.followUps ?? [], id: \.self) { ask in
                                Label(ask, systemImage: "questionmark.bubble")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions {
                            Button("Forget", role: .destructive) { faces.forget(person.name) }
                        }
                    }
                    Button {
                        registering = true
                    } label: {
                        Label("Register a person", systemImage: "person.crop.circle.badge.plus")
                    }
                } header: {
                    Text("Registered people")
                } footer: {
                    Text("Only registered people are recognised, and only their words are kept. Swipe a person to forget them: their face and everything remembered about them is deleted.")
                }
            }
        }
        .navigationTitle("People & faces")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $registering) { RegisterView(watch: watch) }
    }

    private func look(_ on: Bool) {
        if on {
            watch.start(server: serverAddress, code: pairingCode, useGlasses: useGlasses)
        } else {
            watch.stop()
        }
    }

    @ViewBuilder
    private var glassesPreview: some View {
        if let picture = glasses.preview {
            // The whole picture, uncropped: this is exactly what the server is sent.
            Image(uiImage: picture)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }
        switch glasses.status {
        case .off, .streaming:
            EmptyView()
        case .starting:
            Label("Connecting to the glasses…", systemImage: "eyeglasses")
        case .waiting:
            Label("Waiting for the glasses' camera. Put them on, unfolded.", systemImage: "eyeglasses")
        case .paused:
            Label("The glasses paused the camera. Tap the temple to carry on.", systemImage: "pause.circle")
        case .problem(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
        }
    }
}

/// A small dot, then the fact.
private struct FactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon.font(.system(size: 5)).foregroundStyle(.secondary)
            configuration.title.font(.footnote)
        }
    }
}

#Preview {
    NavigationStack { FacesView(watch: FaceWatch(faces: FaceClient(), glasses: GlassesCamera())) }
}
