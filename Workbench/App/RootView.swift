import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case overview
    case currentWork
    case tasks
    case notes
    case inbox
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .currentWork:
            return "Current Work"
        case .tasks:
            return "Tasks"
        case .notes:
            return "Notes"
        case .inbox:
            return "Inbox"
        case .settings:
            return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "square.grid.2x2"
        case .currentWork:
            return "scope"
        case .tasks:
            return "checklist"
        case .notes:
            return "note.text"
        case .inbox:
            return "tray"
        case .settings:
            return "gearshape"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "Start here"
        case .currentWork:
            return "What you are doing now"
        case .tasks:
            return "Things to finish"
        case .notes:
            return "Ideas and fragments"
        case .inbox:
            return "Inputs to triage"
        case .settings:
            return "App configuration"
        }
    }
}

struct RootView: View {
    @State private var selection: WorkspaceSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(WorkspaceSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Workbench")
        } detail: {
            detailView(for: selection ?? .overview)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detailView(for section: WorkspaceSection) -> some View {
        switch section {
        case .overview:
            HomeView()
        case .currentWork:
            PlaceholderSectionView(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                bullets: [
                    "Define how current work should be captured.",
                    "Decide which context should follow you across sessions.",
                    "Keep this surface lightweight until the product idea matures."
                ]
            )
        case .tasks:
            PlaceholderSectionView(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                bullets: [
                    "Collect lightweight task concepts.",
                    "Avoid premature workflow decisions.",
                    "Promote only durable rules into docs."
                ]
            )
        case .notes:
            PlaceholderSectionView(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                bullets: [
                    "Use this area for raw thinking.",
                    "Separate unstable ideas from durable product decisions.",
                    "Promote recurring patterns into the PRD."
                ]
            )
        case .inbox:
            PlaceholderSectionView(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                bullets: [
                    "Future home for mail, captures, and imported context.",
                    "Do not design integrations until the product pressure is clearer.",
                    "Start from manual input before automation."
                ]
            )
        case .settings:
            PlaceholderSectionView(
                title: section.title,
                subtitle: section.subtitle,
                systemImage: section.systemImage,
                bullets: [
                    "App-level preferences will live here.",
                    "Multi-device concerns can be added later.",
                    "Keep the initial shell simple and easy to evolve."
                ]
            )
        }
    }
}

private struct PlaceholderSectionView: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let bullets: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    bulletList
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .navigationTitle(title)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("This is a placeholder surface for early discovery. Keep structure minimal until the product direction is stable enough to deserve stronger commitments.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bulletList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current guidance")
                .font(.headline)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .padding(.top, 7)
                        .foregroundStyle(.secondary)

                    Text(bullet)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    RootView()
}
