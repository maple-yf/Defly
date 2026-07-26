import DeflyCore
import SwiftUI

struct OverviewView: View {
    @StateObject private var viewModel: OverviewViewModel
    private let onRequestChanges:
        ([AssociationID], HandlerApplication) -> Void

    init(
        workspace: any WorkspaceClient,
        catalog: AssociationCatalog,
        preferences: PreferencesStore,
        onRequestChanges: @escaping
            ([AssociationID], HandlerApplication) -> Void = {
                _,
                _ in
            }
    ) {
        _viewModel = StateObject(
            wrappedValue: OverviewViewModel(
                workspace: workspace,
                catalog: catalog,
                preferences: preferences
            )
        )
        self.onRequestChanges = onRequestChanges
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                status
                assignmentSection(
                    titleKey: "overview.commonGroups",
                    assignments: viewModel.commonGroups
                )
                assignmentSection(
                    titleKey: "overview.pinned",
                    assignments: viewModel.pinned
                )
            }
            .padding(28)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle(Text("overview.title"))
        .task {
            viewModel.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("overview.title")
                    .font(.system(size: 30, weight: .bold))
                Text("overview.subtitle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            Button {
                viewModel.refresh()
            } label: {
                Label("action.refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isRefreshing)
            .accessibilityIdentifier("overview.refresh")
        }
    }

    private var status: some View {
        HStack(spacing: 8) {
            if viewModel.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                Text("overview.refreshing")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("overview.lastUpdated")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func assignmentSection(
        titleKey: String,
        assignments: [OverviewViewModel.Assignment]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(LocalizedStringKey(titleKey))
                .font(.title3.weight(.semibold))

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 260, maximum: 360),
                        spacing: 16
                    )
                ],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(assignments) { assignment in
                    AssignmentCardView(
                        assignment: assignment,
                        requestChange: { application in
                            onRequestChanges(
                                assignment.associations,
                                application
                            )
                        }
                    )
                }
            }
        }
    }
}

private struct AssignmentCardView: View {
    @State private var showsCandidatePicker = false

    let assignment: OverviewViewModel.Assignment
    let requestChange: (HandlerApplication) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: assignment.symbolName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 34, height: 34)
                        .background(
                            Color.blue.opacity(0.12),
                            in: RoundedRectangle(
                                cornerRadius: 9,
                                style: .continuous
                            )
                        )
                        .accessibilityHidden(true)

                    Text(LocalizedStringKey(assignment.titleKey))
                        .font(.headline)
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    ApplicationIconView(
                        application: representedApplication,
                        size: 42
                    )
                }

                HStack(spacing: 10) {
                    handlerName
                        .font(.body.weight(.medium))

                    Spacer()
                }

                HStack(spacing: 6) {
                    ForEach(
                        Array(assignment.tags.prefix(3)),
                        id: \.self
                    ) { tag in
                        Text(tag)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Color.secondary.opacity(0.1),
                                in: Capsule()
                            )
                    }

                    if assignment.tags.count > 3 {
                        Text("+\(assignment.tags.count - 3)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showsCandidatePicker = true
                } label: {
                    Label(
                        "overview.changeDefaultApplication",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(assignment.candidates.isEmpty)
                .popover(
                    isPresented: $showsCandidatePicker,
                    arrowEdge: .bottom
                ) {
                    candidatePicker
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.card.\(assignment.id)")
    }

    private var candidatePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("overview.chooseApplication")
                .font(.headline)

            ForEach(assignment.candidates) { application in
                Button {
                    showsCandidatePicker = false
                    requestChange(application)
                } label: {
                    HStack(spacing: 10) {
                        ApplicationIconView(
                            application: application,
                            size: 30
                        )
                        Text(application.displayName)
                        Spacer(minLength: 16)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 5)
            }
        }
        .padding(16)
        .frame(minWidth: 230)
    }

    private var representedApplication: HandlerApplication? {
        guard case .application(let application) =
            assignment.handlerState else {
            return nil
        }
        return application
    }

    @ViewBuilder
    private var handlerName: some View {
        switch assignment.handlerState {
        case .application(let application):
            Text(application.displayName)
        case .mixed:
            Text("overview.mixedApplications")
        case .notAssigned:
            Text("overview.notAssigned")
        }
    }
}
