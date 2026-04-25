import SwiftUI

struct CaptureSheet: View {
    let currentSession: WorkSession
    let primaryNode: GoalNode
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                Panel(title: "Optional Placement", systemImage: "paperclip") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(currentSession.title, systemImage: "scope")
                        Label(primaryNode.title, systemImage: "point.3.connected.trianglepath.dotted")
                        Text("Capture can save before final classification. Persistence belongs to task 0010.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("New Capture")
            .accessibilityIdentifier("capture-sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct SessionAttachSheet: View {
    let activeSession: WorkSession
    let recentSessions: [WorkSession]
    let attach: (WorkSession) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Current") {
                    Button(activeSession.title) {
                        attach(activeSession)
                        dismiss()
                    }
                }

                Section("Recent") {
                    ForEach(recentSessions) { session in
                        Button(session.title) {
                            attach(session)
                            dismiss()
                        }
                    }
                }

                Section("Create") {
                    Button("Create new session placeholder") {
                        attach(activeSession)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Attach Session")
            .accessibilityIdentifier("session-attach-sheet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct NodeEditSheet: View {
    let node: GoalNode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Node") {
                    Text(node.title)
                    Text(node.summary)
                }

                Section("First supported actions") {
                    Label("Rename or edit node", systemImage: "square.and.pencil")
                    Label("Connect nearby node", systemImage: "link")
                    Label("Attach session or capture", systemImage: "paperclip")
                }
            }
            .navigationTitle("Edit Node")
            .accessibilityIdentifier("node-edit-sheet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct HostProfileSheet: View {
    let host: HostProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Host Profile") {
                    Text(host.name)
                    Text(host.address)
                    Text(host.note)
                }

                Section("Deferred") {
                    Text("Credential handling and real SSH/SFTP setup belong to tasks 0010 and 0011.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Host Profile")
            .accessibilityIdentifier("host-profile-sheet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
