import SwiftUI

// The People tab (the server's registered people, and each one's profile) and the Recaps
// tab (what the last conversation left behind).

/// "today, 2:14 PM", "yesterday", or "Nov 7".
enum When {
    static func text(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today, " + date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - 12a · People

struct PeopleTab: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationStack(path: $model.peoplePath) {
            PeopleScreen(model: model)
                .navigationDestination(for: String.self) { name in
                    ProfileScreen(model: model, name: name)
                }
        }
    }
}

struct PeopleScreen: View {
    let model: AppModel

    @AppStorage("serverAddress") private var serverAddress = ""
    @State private var query = ""

    private var faces: FaceClient { model.faces }
    private var hasServer: Bool { !serverAddress.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Most recently seen first, then by name.
    private var people: [FaceClient.Person] {
        let wanted = query.trimmingCharacters(in: .whitespaces).lowercased()
        return faces.people
            .filter { person in
                wanted.isEmpty || ([person.name, person.relationship, person.recall ?? ""] + (person.facts ?? []))
                    .contains { $0.lowercased().contains(wanted) }
            }
            .sorted {
                let a = $0.lastSeen?.date ?? .distantPast, b = $1.lastSeen?.date ?? .distantPast
                return a == b ? $0.name < $1.name : a > b
            }
    }

    var body: some View {
        Screen {
            TitleRow("People", model: model)

            HStack(spacing: 8) {
                Icon("magnifyingglass", size: 20).foregroundStyle(Theme.subtle)
                TextField("Search names, relationships", text: $query)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 10)

            Callout(icon: "person.badge.plus", title: "Register a person", detail: "Name, who they are, their OK, and a few photos.") {
                model.sheet = .register(name: nil)
            }
            .padding(.top, 14)

            SectionTitle("Registered · \(faces.people.count)").padding(.top, 20)

            if case .failed(let reason) = faces.state, hasServer {
                ProblemNote(reason).padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 0) {
                if people.isEmpty {
                    empty.padding(16)
                }
                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    if index > 0 { Hairline(inset: 70) }
                    Button {
                        model.peoplePath = [person.name]
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(name: person.name, look: person.lastSeen?.date.map(Calendar.current.isDateInToday) == true ? .saved : .plain)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(person.name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text(Self.line(under: person)).font(.subheadline).foregroundStyle(Theme.muted).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Icon("chevron.right", size: 16, weight: .semibold).foregroundStyle(Theme.outline)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
            .padding(.top, 8)

            Text("Only registered people are recognised, and only their words are kept.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .padding(.top, 8).padding(.leading, 4)
        }
        .onAppear { model.reach() }
    }

    @ViewBuilder
    private var empty: some View {
        if !hasServer {
            VStack(alignment: .leading, spacing: 10) {
                Text("People are kept on your server. Connect to it to see them and to register someone.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                Button("Connect to a server") { model.sheet = .device(.server) }.buttonStyle(SmallButton())
            }
        } else if faces.state == .connecting {
            HStack(spacing: 10) {
                ProgressView()
                Text("Connecting to the server…").font(.subheadline).foregroundStyle(Theme.muted)
            }
        } else if faces.state != .live {
            VStack(alignment: .leading, spacing: 10) {
                Text("Not connected to the server, so the people on it cannot be shown.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                Button("Try again") { model.reach() }.buttonStyle(SmallButton())
            }
        } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("No one matches “\(query)”.").font(.subheadline).foregroundStyle(Theme.muted)
        } else {
            Text("Nobody yet. Register someone to be recognised.").font(.subheadline).foregroundStyle(Theme.muted)
        }
    }

    /// "Daughter · seen today, 2:14 PM"
    static func line(under person: FaceClient.Person) -> String {
        let seen = person.lastSeen?.date.map { "seen " + When.text($0) } ?? "not seen yet"
        guard !person.relationship.isEmpty else { return seen.prefix(1).uppercased() + seen.dropFirst() }
        return person.relationship.prefix(1).uppercased() + person.relationship.dropFirst() + " · " + seen
    }
}

// MARK: - 12b · Profile

/// What the server remembers about one person: the last conversation, lasting facts,
/// things to ask next time.
struct ProfileScreen: View {
    let model: AppModel
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    private var person: FaceClient.Person? { model.person(named: name) }

    var body: some View {
        Screen {
            BackLink(label: "People") { dismiss() }
            if let person {
                profile(person)
            } else {
                Text(model.faces.state == .live ? "\(name) is not registered." : "Not connected to the server, so \(name)’s profile cannot be shown.")
                    .font(.body).foregroundStyle(Theme.muted)
                    .padding(.top, 16)
            }
        }
    }

    @ViewBuilder
    private func profile(_ person: FaceClient.Person) -> some View {
        let photos = person.photos ?? 0
        HStack(spacing: 12) {
            Avatar(name: person.name)
            VStack(alignment: .leading, spacing: 0) {
                Text(person.name).font(.title.weight(.bold))
                Text((person.relationship.isEmpty ? "" : "Your \(person.relationship) · ") + "\(photos) photo\(photos == 1 ? "" : "s")")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .padding(.top, 8)

        Button {
            model.faces.say(person)
        } label: {
            HStack(spacing: 12) {
                Tile("speaker.wave.2", size: 36)
                Text("“\(person.intro)”").font(.callout.weight(.medium)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .card(padding: 16)
        }
        .buttonStyle(PressStyle())
        .accessibilityHint("Says it out loud")
        .padding(.top, 16)

        if let recall = person.recall, !recall.isEmpty {
            SectionTitle("Last time" + (person.lastSeen?.date.map { " · " + When.text($0) } ?? "")).padding(.top, 20)
            Text(recall).font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .card(padding: 16)
                .padding(.top, 8)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing remembered yet").font(.body.weight(.semibold))
                Text("After your next conversation with \(person.name), Familiar notes what to remember.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
            .card(padding: 16)
            .padding(.top, 20)
        }

        if let facts = person.facts, !facts.isEmpty {
            SectionTitle("Good to know").padding(.top, 20)
            lines(facts).padding(.top, 8)
        }

        if let asks = person.followUps, !asks.isEmpty {
            SectionTitle("You could ask").padding(.top, 20)
            lines(asks).padding(.top, 8)
        }

        Button {
            model.sheet = .register(name: person.name)
        } label: {
            Label("Add photos of \(person.name)", systemImage: "camera")
        }
        .buttonStyle(CapsuleButton(kind: .secondary))
        .padding(.top, 20)

        if confirming {
            VStack(alignment: .leading, spacing: 0) {
                Text("Forget \(person.name)?").font(.body.weight(.semibold))
                Text("Deletes \(person.name)’s face data and profile on the server. It can’t be undone.")
                    .font(.subheadline).foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                HStack(spacing: 10) {
                    Button("Cancel") { confirming = false }.buttonStyle(CapsuleButton(kind: .secondary, height: 48))
                    Button("Forget") {
                        if model.forget(person.name) { dismiss() }
                        confirming = false
                    }
                    .buttonStyle(CapsuleButton(kind: .dangerSolid, height: 48))
                }
                .padding(.top, 14)
            }
            .card(padding: 16)
            .padding(.top, 10)
            .transition(.scale(scale: 0.97).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(duration: 0.35)) { confirming = true }
            } label: {
                Label("Forget \(person.name)", systemImage: "trash")
            }
            .buttonStyle(CapsuleButton(kind: .danger))
            .padding(.top, 10)
        }

        Text("Saved conversation text stays in the server’s conversations folder until someone removes it.")
            .font(.footnote).foregroundStyle(Theme.muted)
            .padding(.top, 8).padding(.leading, 4)
    }

    private func lines(_ texts: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(texts.enumerated()), id: \.offset) { index, text in
                if index > 0 { Hairline(inset: 16) }
                Text(text).font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .card()
    }
}

// MARK: - 11 · Conversation

/// What was kept when Listen was switched off, and what to remember from it.
struct RecapScreen: View {
    let model: AppModel

    private var listening: Bool { model.isListening }

    var body: some View {
        Screen {
            if let conversation = model.last {
                TitleRow("Conversation", model: model)
                Text(Self.heading(conversation)).font(.subheadline).foregroundStyle(Theme.muted).padding(.top, 2)
                if listening { listeningNote.padding(.top, 16) }
                // What Gemini wrote arrives a few seconds after the conversation ends.
                TimelineView(.periodic(from: .now, by: 5)) { moment in
                    VStack(alignment: .leading, spacing: 0) { recap(conversation, now: moment.date) }
                }
            } else {
                TitleRow("Conversations", model: model)
                if listening {
                    listeningNote.padding(.top, 20)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nothing yet").font(.body.weight(.semibold))
                        Text("When you stop listening, who you talked with and what to remember shows up here.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    .card(padding: 16)
                    .padding(.top, 20)
                }
            }
        }
        .onAppear { model.reach() }
    }

    private var listeningNote: some View {
        HStack(spacing: 12) {
            LiveDot()
            VStack(alignment: .leading, spacing: 2) {
                Text("Listening now").font(.body.weight(.semibold))
                Text("This page shows the new conversation when you stop.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 16)
    }

    @ViewBuilder
    private func recap(_ conversation: AppModel.Conversation, now: Date) -> some View {
        if conversation.people.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Tile("eye.slash", size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing was kept").font(.body.weight(.semibold))
                    Text("Nobody registered took part, so the conversation left nothing behind.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            .card(padding: 16)
            .padding(.top, 18)
        } else {
            SectionTitle("What to remember").padding(.top, 20)
            VStack(spacing: 10) {
                ForEach(conversation.people, id: \.self) { name in
                    remembered(name, in: conversation, now: now)
                }
            }
            .padding(.top, 8)

            let asks = conversation.people.flatMap { name in
                (model.person(named: name)?.followUps ?? []).map { (name: name, ask: $0) }
            }
            if !asks.isEmpty {
                SectionTitle("Next time, you could ask").padding(.top, 20)
                VStack(spacing: 0) {
                    ForEach(Array(asks.enumerated()), id: \.offset) { index, item in
                        if index > 0 { Hairline(inset: 16) }
                        HStack(spacing: 12) {
                            Icon("checkmark.circle", size: 18).foregroundStyle(Theme.blue)
                            Text(item.ask).font(.callout).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Text(item.name).font(.footnote).foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                }
                .card()
                .padding(.top, 8)
            }
        }

        SectionTitle("What was kept").padding(.top, 20)
        VStack(spacing: 0) {
            IconLine(icon: "doc.text", text: "\(conversation.kept) line\(conversation.kept == 1 ? "" : "s") of text, on your server")
            Hairline(inset: 48)
            IconLine(icon: "eye.slash",
                     text: conversation.hidden == 0
                        ? "Nobody unregistered was heard"
                        : "\(conversation.hidden) time\(conversation.hidden == 1 ? "" : "s"), someone not registered spoke: not kept",
                     color: Theme.subtle)
            Hairline(inset: 48)
            IconLine(icon: "mic", text: "No audio stored", color: Theme.subtle)
        }
        .card()
        .padding(.top, 8)

        if !listening && !model.transcript.lines.isEmpty {
            HStack {
                SectionTitle("What was said")
                Spacer()
                Button("Clear") { model.transcript.clear() }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.blue)
            }
            .padding(.top, 20)
            TranscriptLines(transcript: model.transcript)
                .card(padding: 16)
                .padding(.top, 8)
            Text("Shown on this iPhone until you clear it or listen again.")
                .font(.footnote).foregroundStyle(Theme.muted)
                .padding(.top, 8).padding(.leading, 4)
        }
    }

    private func remembered(_ name: String, in conversation: AppModel.Conversation, now: Date) -> some View {
        let person = model.person(named: name)
        let recall = person?.recall ?? ""
        // The server stamps a profile when it has read the conversation.
        let fresh = (person?.lastSeen?.date).map { $0 >= conversation.started.addingTimeInterval(-5) } ?? false
        let waiting = !fresh && now.timeIntervalSince(conversation.ended) < 45
        return Button {
            model.open(person: name)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Avatar(name: name, look: .saved)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(name).font(.body.weight(.semibold)).foregroundStyle(Theme.ink)
                        if let relationship = person?.relationship, !relationship.isEmpty {
                            Text("· \(relationship.prefix(1).uppercased() + relationship.dropFirst())")
                                .font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                    if waiting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Working out what to remember…").font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    } else {
                        Text(recall.isEmpty ? "Nothing new to remember from this conversation." : recall)
                            .font(.callout)
                            .foregroundStyle(recall.isEmpty ? Theme.muted : Theme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Icon("chevron.right", size: 16, weight: .semibold).foregroundStyle(Theme.outline).padding(.top, 4)
            }
            .card(padding: 16)
        }
        .buttonStyle(PressStyle())
    }

    /// "Today · 17 min"
    static func heading(_ conversation: AppModel.Conversation) -> String {
        let day = Calendar.current.isDateInToday(conversation.ended) ? "Today" : conversation.ended.formatted(.dateTime.month(.abbreviated).day())
        let minutes = Int((conversation.ended.timeIntervalSince(conversation.started) / 60).rounded())
        let long = minutes < 1 ? "under a minute" : minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
        return "\(day), \(conversation.started.formatted(date: .omitted, time: .shortened)) · \(long)"
    }
}
