import AppKit
import DeflyCore
import SwiftUI
import UniformTypeIdentifiers

struct ExplorerView: View {
    @Environment(\.locale) private var locale
    @StateObject private var viewModel: ExplorerViewModel
    @State private var selectedID: String?

    private let onRequestChange:
        (AssociationDescriptor, HandlerApplication) -> Void

    init(
        mode: ExplorerMode,
        catalog: AssociationCatalog,
        workspace: any WorkspaceClient,
        preferences: PreferencesStore,
        applicationLoader: @escaping
            @MainActor () async -> [InstalledApplication],
        onRequestChange: @escaping
            (AssociationDescriptor, HandlerApplication) -> Void = {
                _,
                _ in
            }
    ) {
        _viewModel = StateObject(
            wrappedValue: ExplorerViewModel(
                mode: mode,
                catalog: catalog,
                workspace: workspace,
                preferences: preferences,
                applicationLoader: applicationLoader
            )
        )
        self.onRequestChange = onRequestChange
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                associationList
                inspector
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(
            Text(LocalizedStringKey(viewModel.mode.titleKey))
        )
        .task {
            selectFirstAvailable()
            await viewModel.discoverDeclaredAssociations()
            selectFirstAvailable()
        }
        .onChange(of: viewModel.searchText) {
            selectFirstAvailable()
        }
        .onChange(of: viewModel.filter) {
            selectFirstAvailable()
        }
        .onChange(of: locale.identifier) {
            selectFirstAvailable()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(LocalizedStringKey(viewModel.mode.titleKey))
                    .font(.system(size: 28, weight: .bold))
                Text(LocalizedStringKey(viewModel.mode.subtitleKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)

            if viewModel.isDiscovering {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel(
                        Text("explorer.discovering")
                    )
            }

            Picker(
                "explorer.filter.label",
                selection: $viewModel.filter
            ) {
                ForEach(ExplorerFilter.allCases) { filter in
                    Text(
                        LocalizedStringKey(
                            filter.localizationKey
                        )
                    )
                    .tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 140)
            .accessibilityIdentifier("explorer.filter")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var associationList: some View {
        List(selection: $selectedID) {
            ForEach(viewModel.groups(locale: locale)) { group in
                Section {
                    ForEach(group.descriptors) { descriptor in
                        AssociationRow(
                            descriptor: descriptor,
                            application: viewModel
                                .currentApplication(for: descriptor)
                        )
                        .tag(descriptor.id)
                        .accessibilityIdentifier(
                            "explorer.row.\(descriptor.id)"
                        )
                    }
                } header: {
                    Text(
                        LocalizedStringKey(
                            "category.\(group.category.rawValue)"
                        )
                    )
                }
            }
        }
        .listStyle(.inset)
        .searchable(
            text: $viewModel.searchText,
            prompt: Text("explorer.searchPrompt")
        )
        .frame(
            minWidth: 280,
            idealWidth: 320,
            maxWidth: 390
        )
    }

    @ViewBuilder
    private var inspector: some View {
        if let descriptor = viewModel.descriptor(
            id: selectedID,
            locale: locale
        ) {
            AssociationInspector(
                descriptor: descriptor,
                localizedName: viewModel.localizedName(
                    for: descriptor,
                    locale: locale
                ),
                currentApplication: viewModel.currentApplication(
                    for: descriptor
                ),
                candidates: viewModel.candidates(for: descriptor),
                chooseOther: {
                    chooseOtherApplication(for: descriptor)
                },
                requestChange: { application in
                    onRequestChange(descriptor, application)
                }
            )
            .id(descriptor.id)
        } else {
            ContentUnavailableView(
                "explorer.noSelection",
                systemImage: "sidebar.left",
                description: Text("explorer.noSelection.description")
            )
            .frame(
                minWidth: 430,
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
    }

    private func selectFirstAvailable() {
        let results = viewModel.filteredDescriptors(locale: locale)
        if let selectedID,
           results.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = results.first?.id
    }

    private func chooseOtherApplication(
        for descriptor: AssociationDescriptor
    ) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(
            fileURLWithPath: "/Applications",
            isDirectory: true
        )
        panel.message = LocalizedText.string(
            "explorer.chooseOther.message",
            locale: locale
        )
        panel.prompt = LocalizedText.string(
            "action.chooseApplication",
            locale: locale
        )

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        let bundle = Bundle(url: url)
        let application = HandlerApplication(
            applicationURL: url,
            bundleIdentifier: bundle?.bundleIdentifier,
            displayName: FileManager.default.displayName(
                atPath: url.path
            ),
            compatibility: .manuallySelected
        )
        onRequestChange(descriptor, application)
    }
}

private struct AssociationRow: View {
    let descriptor: AssociationDescriptor
    let application: HandlerApplication?

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(
                    Color.blue.opacity(0.1),
                    in: RoundedRectangle(
                        cornerRadius: 7,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(
                    LocalizedStringKey(
                        descriptor.localizationKey
                    )
                )
                .lineLimit(1)

                Text(identifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            ApplicationIconView(
                application: application,
                size: 26
            )
        }
        .padding(.vertical, 3)
    }

    private var identifier: String {
        switch descriptor.association {
        case .contentType(let identifier):
            identifier
        case .urlScheme(let scheme):
            "\(scheme):"
        }
    }

    private var symbolName: String {
        switch descriptor.category {
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

private struct AssociationInspector: View {
    let descriptor: AssociationDescriptor
    let localizedName: String
    let currentApplication: HandlerApplication?
    let candidates: [HandlerApplication]
    let chooseOther: () -> Void
    let requestChange: (HandlerApplication) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(localizedName)
                        .font(.system(size: 26, weight: .bold))
                    Text(identifier)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                currentApplicationCard
                metadataCard
                candidateApplicationsCard
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: 430,
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var currentApplicationCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("explorer.currentDefault")
                    .font(.headline)

                if let currentApplication {
                    HStack(spacing: 12) {
                        ApplicationIconView(
                            application: currentApplication,
                            size: 42
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(currentApplication.displayName)
                                .font(.body.weight(.medium))
                            if let bundleIdentifier =
                                currentApplication.bundleIdentifier {
                                Text(bundleIdentifier)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Label(
                        "explorer.noDefault",
                        systemImage: "exclamationmark.circle"
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadataCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("explorer.metadata")
                    .font(.headline)

                LabeledContent("explorer.identifier") {
                    Text(identifier)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }

                if case .contentType = descriptor.association {
                    LabeledContent("explorer.extensions") {
                        TagFlow(
                            values: descriptor.filenameExtensions.map {
                                ".\($0)"
                            }
                        )
                    }

                    LabeledContent("explorer.mimeTypes") {
                        TagFlow(values: descriptor.mimeTypes)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var candidateApplicationsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("explorer.compatibleApplications")
                    .font(.headline)

                if candidates.isEmpty {
                    Text("explorer.noCandidates")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(candidates) { application in
                        HStack(spacing: 11) {
                            ApplicationIconView(
                                application: application,
                                size: 34
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(application.displayName)
                                if application.stableID
                                    == currentApplication?.stableID {
                                    Text("explorer.currentBadge")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }

                            Spacer(minLength: 12)

                            Button("action.setDefault") {
                                requestChange(application)
                            }
                            .disabled(
                                application.stableID
                                    == currentApplication?.stableID
                            )
                        }
                    }
                }

                Divider()

                Button(action: chooseOther) {
                    Label(
                        "action.chooseOtherApplication",
                        systemImage: "plus.app"
                    )
                }
                .buttonStyle(.bordered)

                Label(
                    "explorer.chooseOther.warning",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var identifier: String {
        switch descriptor.association {
        case .contentType(let identifier):
            identifier
        case .urlScheme(let scheme):
            scheme
        }
    }
}

private struct TagFlow: View {
    let values: [String]

    var body: some View {
        if values.isEmpty {
            Text("explorer.none")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 6) {
                ForEach(values, id: \.self) { value in
                    Text(value)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Color.secondary.opacity(0.1),
                            in: Capsule()
                        )
                }
            }
        }
    }
}
