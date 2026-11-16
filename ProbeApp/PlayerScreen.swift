import SwiftUI
#if canImport(ProbeCore)
import ProbeCore
#endif

struct PlayerScreen: View {
    @ObservedObject var app: ProbeApplication
    @Environment(\.scenePhase) private var phase
    private enum FolderField: Hashable { case name, link }
    @FocusState private var focusedField: FolderField?
    @State private var link = ""
    @State private var name = ""
    @State private var showingRoots = false
    @State private var showingQueue = false
    @State private var seeking = false
    @State private var seekValue = 0.0
    @State private var configurationError: String?
    private let lime = Color(red: 0.76, green: 0.96, blue: 0.40)
    private let panel = Color(red: 0.12, green: 0.15, blue: 0.17)

    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        player
                        collection
                    }.padding()
                }
                .onChange(of: focusedField) { field in
                    if let field {
                        withAnimation { proxy.scrollTo(field, anchor: .center) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    // Reposition after the keyboard has reduced the visible viewport.
                    if let focusedField {
                        withAnimation { proxy.scrollTo(focusedField, anchor: .center) }
                    }
                }
            }
            .background(Color(red: 0.06, green: 0.08, blue: 0.09))
            .navigationTitle("OpenMP3")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showingRoots = true } label: { Label("Saved folders", systemImage: "folder") }
                        .disabled(app.scanObservation.state == .scanning)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if focusedField != nil {
                        Button("Done") { focusedField = nil }
                            .accessibilityLabel("Done editing folder")
                    }
                    Button { showingQueue = true } label: { Label("Play queue", systemImage: "list.bullet") }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .tint(lime)
        .sheet(isPresented: $showingRoots) { rootsSheet }
        .sheet(isPresented: $showingQueue) { queueSheet }
        .onChange(of: phase) { if $0 != .active { app.stopScan(backgrounded: true) } }
        .onChange(of: app.playback.seconds) { if !seeking { seekValue = $0 } }
    }

    private var player: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OPEN / MP3").font(.headline.monospaced()).tracking(2)
                Spacer()
                Text(app.playback.state.uppercased()).font(.caption.monospaced()).foregroundColor(lime)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(app.playback.current?.entry.name ?? "Ready when you are")
                    .font(.title3.monospaced()).foregroundColor(lime).lineLimit(2)
                Text("Queue source · " + app.playback.sourceName).font(.caption).foregroundColor(.white.opacity(0.8))
                HStack {
                    Text(time(app.playback.seconds))
                    Spacer()
                    Text(time(app.playback.duration))
                }.font(.body.monospacedDigit()).foregroundColor(lime)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.45)).cornerRadius(8)
            Slider(value: $seekValue, in: 0...max(1, app.playback.duration), onEditingChanged: { editing in
                seeking = editing
                if !editing { app.seek(seconds: seekValue) }
            }).disabled(app.playback.duration <= 0).accessibilityLabel("Playback position")
                .accessibilityValue(time(seekValue))
            HStack(spacing: 12) {
                transport("Previous", icon: "backward.end.fill") { app.previous() }
                transport(app.isPlaybackRequested ? "Pause" : "Play", icon: app.isPlaybackRequested ? "pause.fill" : "play.fill") {
                    app.handle(.toggle)
                }
                transport("Next", icon: "forward.end.fill") { app.next() }
            }.disabled(app.playback.queue.isEmpty)
            HStack {
                Button { app.setShuffle(!app.playback.shuffle) } label: {
                    Label(app.playback.shuffle ? "Shuffle on" : "Shuffle off", systemImage: "shuffle")
                }.accessibilityValue(app.playback.shuffle ? "On" : "Off")
                Spacer()
                Menu {
                    ForEach(RepeatMode.allCases, id: \.self) { mode in
                        Button("Repeat " + mode.rawValue.capitalized) { app.setRepeat(mode) }
                    }
                } label: { Label("Repeat " + app.playback.repeatMode.rawValue.capitalized, systemImage: app.playback.repeatMode == .one ? "repeat.1" : "repeat") }
            }.font(.subheadline).frame(minHeight: 44)
            if let message = app.playback.message {
                Text(message).font(.callout).foregroundColor(.orange)
                if app.playback.state == "failed" || app.playback.state == "paused" {
                    Button("Retry playback") { app.retryPlayback() }.frame(minHeight: 44)
                }
            }
        }
        .padding(14).background(LinearGradient(colors: [panel, Color(red: 0.09, green: 0.11, blue: 0.13)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.16)))
    }
    private func transport(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.title2).frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.white.opacity(0.07)).cornerRadius(8)
        }.accessibilityLabel(title)
    }
    private var collection: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SELECTED FOLDER").font(.caption.monospaced()).foregroundColor(.secondary)
                    Text(app.selectedRootName).font(.headline)
                }
                Spacer()
                if app.selectedRoot != nil {
                    Button(app.scanObservation.state == .scanning ? "Stop scan" : "Rescan") {
                        if app.scanObservation.state == .scanning { app.stopScan() } else { scan() }
                    }.frame(minHeight: 44)
                }
            }
            if app.selectedRoot == nil {
                Text("Your folders. Your music.").font(.title2.bold())
                Text("Paste a public Google Drive folder link to discover its MP3s. Only you choose when music starts.").foregroundColor(.secondary)
            }
            DisclosureGroup(app.selectedRoot == nil ? "Add a public folder" : "Load another folder", isExpanded: Binding(get: { app.selectedRoot == nil || addingFolder }, set: { addingFolder = $0 })) {
                VStack(spacing: 10) {
                    TextField("Folder name (optional)", text: $name).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .name).id(FolderField.name)
                        .submitLabel(.next).onSubmit { focusedField = .link }
                    TextField("Public Google Drive folder link", text: $link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Public folder URL")
                        .focused($focusedField, equals: .link).id(FolderField.link)
                        .submitLabel(.done).onSubmit { focusedField = nil }
                    Button("Load folder") { load() }.frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.borderedProminent).foregroundColor(.black)
                        .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || app.scanObservation.state == .scanning)
                }.padding(.top, 10)
            }.disabled(app.scanObservation.state == .scanning)
            if app.scanObservation.state == .scanning {
                ProgressView("Discovering · \(app.tracks.count) tracks · \(app.scanObservation.folders) folders")
            } else if let status = app.scanStatusText {
                Text(status).font(.headline)
                    .foregroundColor(app.scanObservation.state == .finished ? .primary : .orange)
                    .accessibilityIdentifier("scan-status")
            } else if app.selectedRoot != nil { Text("Ready to scan. Your previous queue is unchanged.").foregroundColor(.secondary) }
            if let error = app.error { Text(error).foregroundColor(.orange) }
            if let error = app.storageError ?? configurationError { Text(error).foregroundColor(.orange) }
            if app.scanObservation.state == .incomplete {
                Text(app.tracks.isEmpty ? "Some tracks may be missing. Try scanning again." : "Some tracks may be missing. You can play the tracks found below.").font(.callout)
            }
            if !app.scanObservation.reasons.isEmpty {
                DisclosureGroup("Scan details") {
                    ForEach(Array(Set(app.scanObservation.reasons)).sorted(), id: \.self) { Text($0).font(.caption) }
                    ForEach(Array(app.failedFolderPaths.enumerated()), id: \.offset) { Text("Could not read: " + $0.element.joined(separator: " / ")).font(.caption) }
                }
                .accessibilityValue(app.scanObservation.reasons.joined(separator: ". "))
                .accessibilityIdentifier("scan-details")
            }
            if !app.scanObservation.coverageNotices.isEmpty {
                DisclosureGroup("Full folder coverage not verified") {
                    ForEach(app.scanObservation.coverageNotices, id: \.self) { Text($0).font(.caption) }
                }.font(.caption).foregroundColor(.secondary)
                    .accessibilityIdentifier("scan-coverage")
            }
            if app.scanObservation.state != .notStarted {
                Text("\(app.scanObservation.shortcuts) shortcuts skipped").font(.caption).foregroundColor(.secondary)
            }
            HStack {
                Button { app.setShuffle(false); app.playAll() } label: { Label("Play all", systemImage: "play.fill") }
                Spacer()
                Button { app.shuffleAll() } label: { Label("Shuffle all", systemImage: "shuffle") }
            }.buttonStyle(.bordered).disabled(!app.canPlayCollection)
            ForEach(folderGroups, id: \.path) { group in
                Text(group.label).font(.headline).padding(.top, 6)
                ForEach(group.tracks) { track in
                    Button { app.playTrack(id: track.id) } label: {
                        HStack(alignment: .top) {
                            Image(systemName: app.playback.current?.id == track.id ? "speaker.wave.2" : "music.note").frame(width: 24)
                            Text(track.entry.name).multilineTextAlignment(.leading).foregroundColor(.primary)
                            Spacer(minLength: 0)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.disabled(!app.canPlayCollection).accessibilityLabel("Play " + track.entry.name + ", " + group.label)
                    Divider()
                }
            }
            Text("Streaming uses mobile data when on cellular. Public folder access is experimental; complete discovery is not yet verified.")
                .font(.footnote).foregroundColor(.secondary).padding(.vertical)
        }
    }
    @State private var addingFolder = false
    private struct FolderGroup {
        let path: [String]
        var tracks: [DiscoveredTrack]
        var label: String { path.isEmpty ? "Root folder" : path.joined(separator: " / ") }
    }
    private var folderGroups: [FolderGroup] {
        var groups: [FolderGroup] = []
        for track in app.tracks {
            let path = track.path
            if let last = groups.last, last.path == path {
                groups[groups.count - 1].tracks.append(track)
            } else { groups.append(FolderGroup(path: path, tracks: [track])) }
        }
        return groups
    }
    private var rootsSheet: some View {
        NavigationView {
            List {
                Section(header: Text("Saved on this iPhone"), footer: Text("Removing a folder only removes its saved link and browsing results. Your music keeps playing.")) {
                    ForEach(app.savedRoots) { root in
                        Button {
                            app.selectSavedRoot(id: root.id)
                            showingRoots = false
                        } label: {
                            HStack { Text(root.name); Spacer(); if app.selectedRoot?.id == root.id { Image(systemName: "checkmark") } }.frame(minHeight: 44)
                        }
                    }.onDelete { offsets in
                        let ids = offsets.map { app.savedRoots[$0].id }
                        for id in ids { app.removeSavedRoot(id: id) }
                    }
                }
                Button("Add another folder") { addingFolder = true; showingRoots = false }
            }.navigationTitle("Saved folders").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingRoots = false } } }
        }.preferredColorScheme(.dark)
    }
    private var queueSheet: some View {
        NavigationView {
            List {
                Section(header: Text("Queue source · " + app.playback.sourceName)) {
                    if app.playback.queue.isEmpty { Text("Choose Play all or a track to start a queue.") }
                    ForEach(Array(app.playback.queue.enumerated()), id: \.element.id) { index, track in
                        HStack {
                            Text("\(index + 1)").foregroundColor(.secondary).frame(minWidth: 28)
                            VStack(alignment: .leading) {
                                Text(track.entry.name)
                                Text(track.path.isEmpty ? "Root folder" : track.path.joined(separator: " / ")).font(.caption).foregroundColor(.secondary)
                                if app.playback.unavailableIDs.contains(track.id) { Text("Unavailable").font(.caption).foregroundColor(.orange) }
                            }
                            Spacer()
                            if app.playback.index == index { Image(systemName: "speaker.wave.2").accessibilityLabel("Current track") }
                        }.frame(minHeight: 44)
                    }
                }
            }.navigationTitle("Play queue").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingQueue = false } } }
        }.preferredColorScheme(.dark)
    }
    private func load() {
        focusedField = nil
        app.selectRoot(link)
        guard app.selectedRoot != nil else { return }
        app.saveSelectedRoot(name: name)
        addingFolder = false
        name = ""; link = ""
        if app.scanObservation.state == .notStarted { scan() }
    }
    private func scan() {
        guard let data = Bundle.main.object(forInfoDictionaryKey: "OpenMP3ScanControls") as? [String: Any],
              let json = try? JSONSerialization.data(withJSONObject: data),
              let controls = try? JSONDecoder().decode(ExperimentControls.self, from: json), controls.isValid else {
            configurationError = "Scan configuration is missing. Rebuild with the project generator."
            return
        }
        configurationError = nil
        Task { await app.scan(controls: controls) }
    }
    private func time(_ seconds: Double) -> String {
        let whole = Int(max(0, min(seconds.isFinite ? seconds : 0, 999_999)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
