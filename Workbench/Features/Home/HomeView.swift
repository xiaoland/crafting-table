import SwiftUI

struct HomeView: View {
    private let cards: [PlaceholderCard] = [
        PlaceholderCard(
            title: "What exists now",
            systemImage: "square.stack.3d.up",
            body: "A minimal iPad-first SwiftUI shell, a lean product-doc foundation, and room to discuss the real shape of the product before committing to heavy implementation."
        ),
        PlaceholderCard(
            title: "What to discuss next",
            systemImage: "bubble.left.and.bubble.right",
            body: "Clarify the core user loop, define what “working forest” should mean in practice, and decide which surfaces deserve real implementation first."
        ),
        PlaceholderCard(
            title: "How to use this stage",
            systemImage: "compass",
            body: "Treat this app as a discovery workspace. Use it to hold direction, not final answers. Promote only durable decisions into documentation and code."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                cardsSection
                nextStepsSection
            }
            .padding(28)
            .frame(maxWidth: 960, alignment: .leading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Workbench")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Discovery-stage foundation", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Build the workbench slowly.")
                .font(.largeTitle.bold())

            Text("The current goal is not feature completeness. The goal is to create a calm starting point for product discussion, documentation, and later implementation.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Current snapshot")
                .font(.title2.weight(.semibold))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240), spacing: 16, alignment: .top)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(cards) { card in
                    PlaceholderCardView(card: card)
                }
            }
        }
    }

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Good next steps")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                StepRow(
                    index: 1,
                    title: "Define the primary promise",
                    detail: "What should this workbench help you do better than notes, reminders, or a calendar app?"
                )

                StepRow(
                    index: 2,
                    title: "Name the first durable surface",
                    detail: "Pick one surface worth shaping first, such as current work, task review, or contextual capture."
                )

                StepRow(
                    index: 3,
                    title: "Keep docs ahead of implementation pressure",
                    detail: "Document pressures, claims, and open questions before turning uncertain ideas into architecture."
                )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
        }
    }
}

private struct PlaceholderCard: Identifiable {
    let title: String
    let systemImage: String
    let body: String

    var id: String { title }
}

private struct PlaceholderCardView: View {
    let card: PlaceholderCard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: card.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)

            Text(card.title)
                .font(.headline)

            Text(card.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }
}

private struct StepRow: View {
    let index: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
