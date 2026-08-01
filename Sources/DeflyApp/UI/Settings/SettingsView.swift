import DeflyCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var container: AppContainer

    private let pinOptions: [PinnedItemOption]

    init(
        container: AppContainer,
        catalog: AssociationCatalog
    ) {
        self.container = container

        let descriptorOptions = catalog.snapshot().map {
            descriptor in
            PinnedItemOption(
                id: descriptor.id,
                localizationKey: descriptor.localizationKey,
                symbolName: Self.symbolName(
                    for: descriptor.category
                )
            )
        }
        let smartGroupOptions =
            BuiltInAssociationCatalog.smartGroups.map { group in
                PinnedItemOption(
                    id: "smart:\(group.id)",
                    localizationKey: group.localizationKey,
                    symbolName: group.id == "browser"
                        ? "safari"
                        : group.id == "commonImages"
                            ? "photo.on.rectangle.angled"
                            : "envelope"
                )
            }

        let allOptions = descriptorOptions + smartGroupOptions
        let defaultOrder = Dictionary(
            uniqueKeysWithValues:
                PreferencesStore.defaultPinnedAssociationKeys
                    .enumerated()
                    .map { ($0.element, $0.offset) }
        )
        pinOptions = allOptions.sorted { left, right in
            let leftOrder = defaultOrder[left.id] ?? Int.max
            let rightOrder = defaultOrder[right.id] ?? Int.max
            if leftOrder != rightOrder {
                return leftOrder < rightOrder
            }
            return left.id < right.id
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                languageCard
                pinnedItemsCard
                aboutCard
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(Text("nav.settings"))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("nav.settings")
                .font(.system(size: 30, weight: .bold))
            Text("settings.subtitle")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var languageCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    "settings.language",
                    systemImage: "character.bubble"
                )
                .font(.headline)

                Picker(
                    "settings.language",
                    selection: languageBinding
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(
                            LocalizedStringKey(
                                language.localizationKey
                            )
                        )
                        .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 260, alignment: .leading)
                .accessibilityIdentifier("settings.language")

                Text("settings.language.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pinnedItemsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(
                    "settings.pinnedItems",
                    systemImage: "pin"
                )
                .font(.headline)

                Text("settings.pinnedItems.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: 220,
                                maximum: 320
                            ),
                            spacing: 10
                        )
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(pinOptions) { option in
                        Toggle(
                            isOn: pinBinding(for: option.id)
                        ) {
                            Label {
                                Text(
                                    LocalizedStringKey(
                                        option.localizationKey
                                    )
                                )
                            } icon: {
                                Image(systemName: option.symbolName)
                                    .foregroundStyle(.blue)
                                    .accessibilityHidden(true)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier(
                            "settings.pin.\(option.id)"
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutCard: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                DeflyIconView(size: 64)

                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("settings.about")
                            .font(.title3.weight(.semibold))

                        Spacer(minLength: 24)

                        HStack(spacing: 6) {
                            Text("settings.version")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(version)
                                .font(.body.monospacedDigit())
                        }
                    }

                    Text("brand.tagline")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let repositoryURL = URL(
                        string: "https://github.com/maple-yf/Defly"
                    ) {
                        Link(destination: repositoryURL) {
                            Label(
                                "settings.repository",
                                systemImage: "arrow.up.right.square"
                            )
                        }
                    }

                    Text("settings.openSourceDescription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.aboutBrand")
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: {
                container.language
            },
            set: {
                container.setLanguage($0)
            }
        )
    }

    private func pinBinding(for key: String) -> Binding<Bool> {
        Binding(
            get: {
                container.pinnedAssociationKeys.contains(key)
            },
            set: { isPinned in
                container.setPinned(key, isPinned: isPinned)
            }
        )
    }

    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.1"
    }

    private static func symbolName(
        for category: AssociationDescriptor.Category
    ) -> String {
        switch category {
        case .web:
            "globe"
        case .communication:
            "bubble.left.and.bubble.right"
        case .document:
            "doc.text"
        case .image:
            "photo"
        case .media:
            "play.rectangle"
        case .development:
            "chevron.left.forwardslash.chevron.right"
        case .archive:
            "archivebox"
        }
    }
}

private struct PinnedItemOption: Identifiable {
    let id: String
    let localizationKey: String
    let symbolName: String
}
