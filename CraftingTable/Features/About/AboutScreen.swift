import SwiftUI

struct AboutScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .center, spacing: 24) {
                        Image("AppLogo")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
                            .accessibilityLabel("Crafting Table logo")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Crafting Table")
                                .font(.largeTitle.weight(.semibold))

                            Text("Personal internal build")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        AboutInfoRow(title: "Version", value: appVersion)
                        AboutInfoRow(title: "Build", value: buildNumber)
                        AboutInfoRow(title: "Icon", value: "Build-time generated")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("About")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

private struct AboutInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 24)

            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
    }
}

#Preview {
    AboutScreen()
}
