import SwiftUI

struct RemoteControlScreen: View {
    let state: RemoteConnectionState
    let hosts: [HostProfile]
    let selectedHost: HostProfile?
    let linkedSession: WorkSession?
    let attachSession: () -> Void
    let editHost: () -> Void
    let connect: (HostProfile) -> Void
    let disconnect: () -> Void
    let returnToSession: (WorkSession) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    RemoteHeader(
                        state: state,
                        host: selectedHost,
                        linkedSession: linkedSession,
                        attachSession: attachSession,
                        returnToSession: returnToSession
                    )

                    switch state {
                    case .disconnected:
                        disconnectedContent
                    case .connected:
                        connectedContent
                    }
                }
                .padding(24)
            }
            .navigationTitle("Remote Control")
            .accessibilityIdentifier("remote-control-screen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: editHost) {
                        Label("Edit Host", systemImage: "server.rack")
                    }
                    .accessibilityIdentifier("remote-edit-host-button")
                }
            }
        }
    }

    private var disconnectedContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                hostList
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                remoteContinuity
                    .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 16) {
                hostList
                remoteContinuity
            }
        }
    }

    private var connectedContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                terminalPlaceholder
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                transferPanel
                    .frame(width: 300)
            }

            VStack(alignment: .leading, spacing: 16) {
                terminalPlaceholder
                transferPanel
            }
        }
    }

    private var hostList: some View {
        Panel(title: "Saved Hosts", systemImage: "server.rack") {
            VStack(spacing: 10) {
                ForEach(hosts) { host in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(host.name)
                                .font(.headline)

                            Text(host.address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(host.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Button {
                            connect(host)
                        } label: {
                            Label("Connect", systemImage: "bolt.horizontal")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("remote-connect-\(host.id)")
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var remoteContinuity: some View {
        Panel(title: "Session Linkage", systemImage: "link") {
            VStack(alignment: .leading, spacing: 12) {
                if let linkedSession {
                    Text("Linked to")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(linkedSession.title)
                        .font(.headline)

                    Text("Host, recency, transfers, and note will be recorded on this session in a later persistence slice.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unattached remote work stays visible here until it is linked to a session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(action: attachSession) {
                        Label("Attach to Session", systemImage: "link.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("remote-attach-session-button")
                }
            }
        }
    }

    private var terminalPlaceholder: some View {
        Panel(title: selectedHost?.name ?? "Connected Host", systemImage: "terminal") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: "Connected", systemImage: "checkmark.circle.fill")

                    Spacer(minLength: 0)

                    Button(action: disconnect) {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("remote-disconnect-button")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("$ hostname")
                    Text(selectedHost?.address ?? "host.local")
                    Text("$ ls ~/work")
                    Text("CraftingTable  notes  uploads")
                    Text("$")
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Color(uiColor: .systemGreen))
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 8))

                Text("Real terminal input, resize, copy and paste, reconnect, and error handling belong to task 0011.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var transferPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Panel(title: "File Transfer", systemImage: "arrow.up.arrow.down") {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: {}) {
                        Label("Upload File", systemImage: "arrow.up.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("remote-upload-placeholder-button")

                    Button(action: {}) {
                        Label("Download File", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("remote-download-placeholder-button")

                    Text("Transfer implementation is reserved for the remote-control depth task.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Panel(title: "Continuity Note", systemImage: "note.text") {
                Text("Record outcome or next step after remote work. Persistence is reserved for task 0010.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RemoteHeader: View {
    let state: RemoteConnectionState
    let host: HostProfile?
    let linkedSession: WorkSession?
    let attachSession: () -> Void
    let returnToSession: (WorkSession) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ScreenIntro(
                title: "Remote Control",
                subtitle: subtitle,
                systemImage: "terminal"
            )

            Spacer(minLength: 0)

            if let linkedSession {
                Button {
                    returnToSession(linkedSession)
                } label: {
                    Label(linkedSession.title, systemImage: "link")
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("remote-return-session-button")
            } else {
                Button(action: attachSession) {
                    Label("Attach to Session", systemImage: "link.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("remote-header-attach-session-button")
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var subtitle: String {
        switch state {
        case .disconnected:
            return "Choose a saved host and keep session linkage visible."
        case .connected:
            return "Connected to \(host?.name ?? "host") with terminal and transfer placeholders."
        }
    }
}
