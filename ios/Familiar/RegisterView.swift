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
    @State private var picked: [PhotosPickerItem] = []
    @State private var takingPhoto = false
    @State private var choosingFile = false
    /// Photos taken or chosen but not sent yet. They can be gathered before the name is
    /// typed; nothing leaves the phone until the Register button is tapped.
    @State private var waiting: [Data] = []
    /// Why the last photo could not be used, or nil.
    @State private var photoProblem: String?
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
                        if let jpeg = watch.latestJPEG { waiting.append(jpeg) }
                    } label: {
                        Label(watch.usingGlasses ? "Use what the glasses see now" : "Use the picture above", systemImage: "camera.viewfinder")
                    }
                    .disabled(watch.latestJPEG == nil)
                    Button {
                        photoProblem = nil
                        // The iPhone has one camera to give: the live picture pauses while the photo is taken.
                        if !watch.usingGlasses { watch.phone.stop() }
                        takingPhoto = true
                    } label: {
                        Label("Take a photo with the iPhone", systemImage: "camera.fill")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    PhotosPicker(selection: $picked, maxSelectionCount: 5, matching: .images) {
                        Label("Choose photos from the library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        photoProblem = nil
                        choosingFile = true
                    } label: {
                        Label("Upload a photo from Files", systemImage: "folder")
                    }
                    if !waiting.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(waiting.enumerated()), id: \.offset) { index, jpeg in
                                    if let picture = UIImage(data: jpeg) {
                                        Image(uiImage: picture)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(alignment: .topTrailing) {
                                                Button { waiting.remove(at: index) } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.title3)
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(.white, .black.opacity(0.6))
                                                }
                                                .buttonStyle(.plain)
                                                .padding(2)
                                                .accessibilityLabel("Remove this photo")
                                            }
                                    }
                                }
                            }
                        }
                        Button {
                            for jpeg in waiting { faces.enrol(name: trimmedName, relationship: relationship, jpeg: jpeg) }
                            waiting = []
                        } label: {
                            Label("Register \(trimmedName.isEmpty ? "them" : trimmedName) with \(waiting.count == 1 ? "this photo" : "these \(waiting.count) photos")", systemImage: "person.crop.circle.badge.plus")
                                .bold()
                        }
                        .disabled(!canAdd)
                        if !canAdd {
                            Text(trimmedName.isEmpty ? "Type their name at the top to register them."
                                 : !agreed ? "Switch on “They agreed to this” to register them."
                                 : "Waiting for the server. Check its address and pairing code on the main screen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Text("This device has no camera of its own. Use the library or Files.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let photoProblem {
                        Label(photoProblem, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
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
                    Text("Three or more works best: straight on, a little left, a little right. One face per photo. Add the photos, then tap Register. Photos are not kept, only a description of the face.")
                }
            }
            .navigationTitle("Register a person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: picked) { _, items in
                guard !items.isEmpty else { return }
                photoProblem = nil
                Task {
                    for item in items {
                        add(try? await item.loadTransferable(type: Data.self))
                    }
                    picked = []
                }
            }
            .fullScreenCover(isPresented: $takingPhoto, onDismiss: {
                if !watch.usingGlasses, watch.isOn { watch.phone.start() }
            }) {
                SystemCamera { photo in add(photo) }
                    .ignoresSafeArea()
            }
            .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                guard case .success(let files) = result else { return }
                for file in files {
                    let allowed = file.startAccessingSecurityScopedResource()
                    add(try? Data(contentsOf: file))
                    if allowed { file.stopAccessingSecurityScopedResource() }
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

    /// One photo, from the iPhone's camera, the library or a file, kept on the phone until
    /// the Register button sends it. The server then says whether it found a face in it.
    private func add(_ photo: Data?) {
        guard let photo, let jpeg = PhoneCamera.jpeg(from: photo) else {
            photoProblem = "That photo could not be opened. Try another one."
            return
        }
        waiting.append(jpeg)
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

/// The iPhone's own camera screen: take one photo, then "Use Photo" or "Retake".
private struct SystemCamera: UIViewControllerRepresentable {
    let onPhoto: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let camera = UIImagePickerController()
        camera.sourceType = .camera
        camera.cameraCaptureMode = .photo
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ camera: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: SystemCamera
        init(_ parent: SystemCamera) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onPhoto((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.9))
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
