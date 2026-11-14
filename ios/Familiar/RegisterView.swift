import PhotosUI
import SwiftUI

/// Register a person: the only way anyone gets recognised, and the only people whose
/// words are ever kept. Needs a yes from them (or their family) before the first photo.
struct RegisterView: View {
    let watch: FaceWatch

    @AppStorage("serverAddress") private var serverAddress = ""
    @AppStorage("pairingCode") private var pairingCode = ""
    @AppStorage("useGlasses") private var useGlasses = false
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relationship = ""
    @State private var agreed = false
    @State private var picked: PhotosPickerItem?
    /// The camera was off when this opened, so it is switched off again on the way out.
    @State private var startedHere = false

    private var faces: FaceClient { watch.faces }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedName.isEmpty && agreed && faces.state == .live }
    private var photos: Int { faces.people.first { $0.name == trimmedName }?.photos ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, e.g. Maria", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Who they are to the wearer, e.g. daughter", text: $relationship)
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("The wearer will hear: “This is \(trimmedName.isEmpty ? "Maria" : trimmedName), your \(relationship.isEmpty ? "daughter" : relationship).”")
                }

                Section {
                    Toggle("They agreed to this", isOn: $agreed)
                } footer: {
                    Text("Registering means Familiar will recognise their face, keep what they say to the wearer as text, and remind the wearer of it next time. Only registered people are ever recorded. They, or family speaking for them, must say yes. They can be forgotten at any time.")
                }

                Section {
                    preview
                    Button {
                        if let jpeg = watch.latestJPEG { faces.enrol(name: trimmedName, relationship: relationship, jpeg: jpeg) }
                    } label: {
                        Label("Take a photo of their face", systemImage: "camera.fill")
                    }
                    .disabled(!canAdd || watch.latestJPEG == nil)
                    PhotosPicker(selection: $picked, matching: .images) {
                        Label("Use a photo from the library", systemImage: "photo")
                    }
                    .disabled(!canAdd)
                    if photos > 0 {
                        Label("\(photos) photo\(photos == 1 ? "" : "s") of \(trimmedName) so far", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if let notice = faces.notice {
                        Text(notice).font(.subheadline).foregroundStyle(.secondary)
                    }
                    if case .failed(let reason) = faces.state {
                        Label(reason, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Three or more works best: straight on, a little left, a little right. One face per photo. Photos are not kept, only a description of the face.")
                }
            }
            .navigationTitle("Register a person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: picked) { _, item in
                guard let item else { return }
                Task {
                    if let photo = try? await item.loadTransferable(type: Data.self), let jpeg = PhoneCamera.jpeg(from: photo) {
                        faces.enrol(name: trimmedName, relationship: relationship, jpeg: jpeg)
                    }
                    picked = nil
                }
            }
            .onAppear {
                guard !watch.isOn else { return }
                startedHere = true
                watch.start(server: serverAddress, code: pairingCode, useGlasses: useGlasses)
            }
            .onDisappear {
                if startedHere { watch.stop() }
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if watch.usingGlasses {
            if let picture = watch.glasses.preview {
                Image(uiImage: picture)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Label("Waiting for the glasses' camera. Put them on, unfolded.", systemImage: "eyeglasses")
                    .foregroundStyle(.secondary)
            }
            if case .problem(let reason) = watch.glasses.status {
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        } else if let problem = watch.phoneProblem {
            Text(problem).font(.subheadline).foregroundStyle(.secondary)
        } else {
            CameraPreview(session: watch.phone.session)
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topTrailing) {
                    Button { watch.phone.flip() } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .padding(10)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .accessibilityLabel("Switch camera")
                }
        }
    }
}
