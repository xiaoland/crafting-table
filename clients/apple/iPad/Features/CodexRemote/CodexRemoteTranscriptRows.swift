import SwiftUI
import UIKit

enum CodexRemoteTranscriptRow: Identifiable {
    case message(CodexRemoteTranscriptEntry)
    case toolCallGroup(CodexRemoteToolCallGroup)

    var id: String {
        switch self {
        case .message(let message):
            return message.id
        case .toolCallGroup(let group):
            return group.id
        }
    }

    static func project(_ entries: [CodexRemoteTranscriptEntry]) -> [CodexRemoteTranscriptRow] {
        var rows: [CodexRemoteTranscriptRow] = []
        var pendingToolCalls: [CodexRemoteTranscriptEntry] = []

        func flushPendingToolCalls() {
            guard pendingToolCalls.isEmpty == false else {
                return
            }

            if pendingToolCalls.count == 1,
               let message = pendingToolCalls.first
            {
                rows.append(.message(message))
            } else {
                rows.append(.toolCallGroup(CodexRemoteToolCallGroup(entries: pendingToolCalls)))
            }

            pendingToolCalls = []
        }

        for entry in entries {
            guard let toolCall = entry.toolCall else {
                flushPendingToolCalls()
                rows.append(.message(entry))
                continue
            }

            if let previous = pendingToolCalls.last?.toolCall,
               pendingToolCalls.last?.turnId == entry.turnId,
               previous.payload.kind == toolCall.payload.kind
            {
                pendingToolCalls.append(entry)
            } else {
                flushPendingToolCalls()
                pendingToolCalls = [entry]
            }
        }

        flushPendingToolCalls()
        return rows
    }
}

struct CodexRemoteToolCallGroup: Identifiable {
    let entries: [CodexRemoteTranscriptEntry]

    var id: String {
        let firstID = entries.first?.id ?? "empty"
        let lastID = entries.last?.id ?? firstID
        return "tool-call-group:\(turnId):\(kind):\(firstID):\(lastID):\(entries.count)"
    }

    var turnId: String {
        entries.first?.turnId ?? ""
    }

    var kind: String {
        entries.first?.toolCall?.payload.kind ?? "toolCall"
    }

    var title: String {
        "\(entries.count) \(pluralTitle)"
    }

    var status: String? {
        entries.reversed().compactMap(\.status).first
    }

    var timestamp: String? {
        entries.reversed().compactMap(\.displayCreatedAt).first
    }

    var systemImage: String {
        switch kind {
        case "commandExecution":
            return "terminal"
        case "fileChange":
            return "doc.text"
        case "webSearch":
            return "magnifyingglass"
        case "mcpToolCall", "dynamicToolCall", "collabAgentToolCall":
            return "wrench.and.screwdriver"
        case "imageGeneration":
            return "photo"
        default:
            return "gearshape"
        }
    }

    var copyText: String {
        entries.enumerated()
            .map { index, entry in
                guard let toolCall = entry.toolCall else {
                    return entry.text
                }

                let detailText = toolCall.payload.detailText
                let body = detailText.isEmpty ? toolCall.payload.summary : detailText
                return "\(index + 1). \(toolCall.payload.displayTitle)\n\(body)"
            }
            .joined(separator: "\n\n")
    }

    private var pluralTitle: String {
        switch kind {
        case "commandExecution":
            return "commands"
        case "fileChange":
            return "file changes"
        case "webSearch":
            return "web searches"
        case "mcpToolCall":
            return "MCP tools"
        case "dynamicToolCall":
            return "tool calls"
        case "collabAgentToolCall":
            return "agent tools"
        case "imageGeneration":
            return "image generations"
        case "imageView":
            return "image views"
        default:
            return kind.isEmpty ? "tool calls" : kind
        }
    }
}

struct CodexRemoteToolCallGroupRow: View {
    let group: CodexRemoteToolCallGroup
    @State private var isShowingToolDetails = false

    var body: some View {
        Button {
            isShowingToolDetails = true
        } label: {
            summaryContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button {
                UIPasteboard.general.string = group.copyText
            } label: {
                Label("Copy details", systemImage: "doc.on.doc")
            }
        }
        .popover(isPresented: $isShowingToolDetails, arrowEdge: .trailing) {
            CodexRemoteToolCallGroupDetailPopover(group: group)
        }
        .accessibilityIdentifier("codex-remote-tool-call-group-row")
    }

    private var summaryContent: some View {
        HStack(spacing: 8) {
            Image(systemName: group.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(group.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let status = group.status,
               status.isEmpty == false
            {
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let timestamp = group.timestamp {
                Text(timestamp)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "square.stack.3d.up")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct CodexRemoteToolCallGroupDetailPopover: View {
    let group: CodexRemoteToolCallGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(group.entries.indices, id: \.self) { index in
                        let entry = group.entries[index]

                        if let toolCall = entry.toolCall {
                            CodexRemoteGroupedToolCallDetailView(
                                index: index,
                                entry: entry,
                                toolCall: toolCall
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 620, height: 560)
        .presentationCompactAdaptation(.sheet)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(group.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let status = group.status,
                       status.isEmpty == false
                    {
                        Text(status)
                    }

                    if let timestamp = group.timestamp {
                        Text(timestamp)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                UIPasteboard.general.string = group.copyText
            } label: {
                Label("Copy details", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy details")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private struct CodexRemoteGroupedToolCallDetailView: View {
    let index: Int
    let entry: CodexRemoteTranscriptEntry
    let toolCall: CodexRemoteToolCallMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index + 1). \(toolCall.payload.displayTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer(minLength: 8)

                if let status = entry.status,
                   status.isEmpty == false
                {
                    Text(status)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let timestamp = entry.displayCreatedAt {
                    Text(timestamp)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if toolCall.payload.summary.isEmpty == false {
                Text(toolCall.payload.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            let rows = toolCall.payload.detailRows

            if rows.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rows) { row in
                        CodexRemoteToolCallDetailRowView(row: row)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CodexRemoteToolCallDetailRowView: View {
    let row: CodexRemoteToolCallDetailRow

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(row.value)
                .font(detailFont)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var detailFont: Font {
        switch row.title {
        case "Command", "Output", "Arguments", "Result", "Error", "Action", "Command actions", "Changes", "Content items", "Agents states":
            return .system(.callout, design: .monospaced)
        default:
            return .callout
        }
    }
}
