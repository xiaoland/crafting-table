import SwiftUI

struct CaptureSheet: View {
    let currentSession: WorkSession
    let primaryNode: GoalNode
    let save: (String, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var linkToCurrentSession = true
    @State private var linkToPrimaryNode = true

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                Panel(title: "Optional Placement", systemImage: "paperclip") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $linkToCurrentSession) {
                            Label(currentSession.title, systemImage: "scope")
                        }

                        Toggle(isOn: $linkToPrimaryNode) {
                            Label(primaryNode.title, systemImage: "point.3.connected.trianglepath.dotted")
                        }

                        Text("Capture can save before final classification.")
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
                        save(
                            text,
                            linkToCurrentSession ? currentSession.id : nil,
                            linkToPrimaryNode ? primaryNode.id : nil
                        )
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
    let createAndAttach: () -> WorkSession
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
                    Button("Create new session") {
                        _ = createAndAttach()
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
    let save: (GoalNode) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var summary: String
    @State private var gridColumn: Int
    @State private var gridRow: Int

    init(node: GoalNode, save: @escaping (GoalNode) -> Void) {
        self.node = node
        self.save = save
        _title = State(initialValue: node.title)
        _summary = State(initialValue: node.summary)
        _gridColumn = State(initialValue: node.gridColumn)
        _gridRow = State(initialValue: node.gridRow)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Node") {
                    TextField("Title", text: $title)
                    TextField("Summary", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Fixed Grid Position") {
                    Stepper("Column \(gridColumn)", value: $gridColumn, in: 0...12)
                    Stepper("Row \(gridRow)", value: $gridRow, in: 0...12)
                }
            }
            .navigationTitle("Edit Node")
            .accessibilityIdentifier("node-edit-sheet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = node
                        updated.title = title
                        updated.summary = summary
                        updated.gridColumn = gridColumn
                        updated.gridRow = gridRow
                        save(updated)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct HostProfileSheet: View {
    let host: HostProfile
    let save: (HostProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var address: String
    @State private var note: String

    init(host: HostProfile, save: @escaping (HostProfile) -> Void) {
        self.host = host
        self.save = save
        _name = State(initialValue: host.name)
        _address = State(initialValue: host.address)
        _note = State(initialValue: host.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Host Profile") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Credential Reference") {
                    Text(host.credentialReferenceID ?? "No credential reference")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Host Profile")
            .accessibilityIdentifier("host-profile-sheet")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = host
                        updated.name = name
                        updated.address = address
                        updated.note = note
                        save(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
