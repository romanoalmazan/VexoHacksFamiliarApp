import PhotosUI
import SwiftUI

/// Register a person: the only way anyone gets recognised, and the only people whose
/// words are ever kept. Needs a yes from them (or their family) before the first photo.
struct RegisterView: View {
    let model: AppModel
    /// Set when adding photos to someone already registered.
    var presetName = ""

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

    private static let relationships = ["daughter", "son", "grandson", "granddaughter", "friend", "neighbour", "carer", "doctor"]

    private var watch: FaceWatch { model.watch }
    private var faces: FaceClient { watch.faces }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canAdd: Bool { !trimmedName.isEmpty && agreed && faces.state == .live }
    private var photos: Int { faces.people.first { $0.name == trimmedName }?.photos ?? 0 }

    var body: some View {
        Screen {
            HStack(alignment: .firstTextBaseline) {
                Text("Register a person").font(.title.weight(.bold)).accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold)).foregroundStyle(Theme.blue)
                    .frame(height: 44)
            }
            .padding(.top, 12)

            HStack(spacing: 12) {
                Tile("speaker.wave.2", size: 36)
                Text("You will hear: ").foregroundStyle(Theme.ink2)
                    + Text("“This is \(trimmedName.isEmpty ? "Maria" : trimmedName), your \(relationship.isEmpty ? "daughter" : relationship).”").fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .card(padding: 16)
            .padding(.top, 10)

            SectionTitle("Name").padding(.top, 16)
            TextField("Their name", text: $name)
                .textInputAutocapitalization(.words)
                .modifier(FilledField())
                .padding(.top, 6)

            SectionTitle("Who they are to the wearer").padding(.top, 14)
            TextField("Daughter, neighbour, carer…", text: $relationship)
                .textInputAutocapitalization(.never)
                .modifier(FilledField())
                .padding(.top, 6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.relationships, id: \.self) { choice in
                        Button {
                            relationship = choice
                        } label: {
                            Chip(relationship == choice ? .live : .plain) { Text(choice.capitalized) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 8)

            SwitchRow(title: "They agreed to this",
                      detail: "Familiar will recognise their face, keep what they say to the wearer as text, and remind the wearer of it next time. They, or family speaking for them, must say yes. They can be forgotten at any time.",
                      isOn: $agreed)
                .padding(.top, 16)

            SectionTitle("Photos of their face").padding(.top, 20)
            VStack(alignment: .leading, spacing: 10) {
                CameraLook(watch: watch, height: 260)
                Button {
                    if let jpeg = watch.latestJPEG { waiting.append(jpeg) }
                } label: {
                    PillLabel(title: watch.usingGlasses ? "Use what the glasses see now" : "Use the picture above", icon: "camera.viewfinder")
                }
                .buttonStyle(PressStyle())
                .disabled(watch.latestJPEG == nil)
                .opacity(watch.latestJPEG == nil ? 0.5 : 1)

                HStack(spacing: 10) {
                    Button {
                        photoProblem = nil
                        // The iPhone has one camera to give: the live picture pauses while the photo is taken.
                        if !watch.usingGlasses { watch.phone.stop() }
                        takingPhoto = true
                    } label: {
                        PillLabel(title: "Take photo", icon: "camera")
                    }
                    .buttonStyle(PressStyle())
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    .opacity(UIImagePickerController.isSourceTypeAvailable(.camera) ? 1 : 0.5)
                    .accessibilityLabel("Take a photo with the iPhone")

                    PhotosPicker(selection: $picked, maxSelectionCount: 5, matching: .images) {
                        PillLabel(title: "From library", icon: "photo.on.rectangle")
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityLabel("Choose photos from the library")
                }
                Button {
                    photoProblem = nil
                    choosingFile = true
                } label: {
                    PillLabel(title: "Upload a photo from Files", icon: "folder")
                }
                .buttonStyle(PressStyle())

                if !waiting.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(waiting.enumerated()), id: \.offset) { index, jpeg in
                                if let picture = UIImage(data: jpeg) {
                                    Image(uiImage: picture)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                } else if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Text("This device has no camera of its own. Use the library or Files.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }

                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { step in
                        Capsule()
                            .fill(photos + waiting.count >= step ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.track))
                            .frame(height: 6)
                    }
                }
                .padding(.top, 4)
                .accessibilityHidden(true)
                Text("Three or more works best: straight on, a little left, a little right. One face per photo. Add the photos, then tap Register.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .card(padding: 16)
            .padding(.top, 8)

            Button {
                for jpeg in waiting { faces.enrol(name: trimmedName, relationship: relationship, jpeg: jpeg) }
                waiting = []
            } label: {
                Text(waiting.isEmpty
                     ? "Register \(trimmedName.isEmpty ? "person" : trimmedName)"
                     : "Register \(trimmedName.isEmpty ? "them" : trimmedName) with \(waiting.count == 1 ? "this photo" : "these \(waiting.count) photos")")
            }
            .buttonStyle(CapsuleButton())
            .disabled(!canAdd || waiting.isEmpty)
            .padding(.top, 18)

            if !canAdd || waiting.isEmpty {
                Text(trimmedName.isEmpty ? "Type their name at the top to register them."
                     : !agreed ? "Switch on “They agreed to this” to register them."
                     : faces.state != .live ? "Waiting for the server. Check its address and pairing code in Settings."
                     : photos > 0 ? "Add more photos, or tap Done."
                     : "Add at least one photo of their face.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
            }

            VStack(alignment: .leading, spacing: 10) {
                if let photoProblem {
                    ProblemNote(photoProblem)
                }
                if photos > 0 {
                    Label("\(photos) photo\(photos == 1 ? "" : "s") of \(trimmedName) so far", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.greenInk)
                }
                if let notice = faces.notice {
                    Text(notice).font(.subheadline).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if case .failed(let reason) = faces.state {
                    ProblemNote(reason)
                }
            }
            .padding(.top, 12)

            Text("The server keeps their name, relationship and numbers describing their face. Not the photos.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
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
            if name.isEmpty, !presetName.isEmpty {
                name = presetName
                // Adding photos to someone already registered: keep who they are.
                if let known = model.person(named: presetName) { relationship = known.relationship }
            }
            guard !watch.isOn else { return }
            startedHere = true
            watch.start(server: serverAddress, code: pairingCode, useGlasses: useGlasses)
        }
        .onDisappear {
            if startedHere {
                watch.stop()
                model.reach()       // the camera goes off, the list of people stays in reach
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
}

/// The design's filled text field.
private struct FilledField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
