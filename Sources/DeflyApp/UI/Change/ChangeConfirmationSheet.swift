import AppKit
import DeflyCore
import SwiftUI

@MainActor
final class ChangeSheetModel: ObservableObject {
    enum Phase {
        case preview(ChangePlan)
        case applying(ChangePlan)
        case result(ChangeReport)
    }

    @Published private(set) var phase: Phase

    private let executor: ChangeExecutor

    init(
        plan: ChangePlan,
        executor: ChangeExecutor
    ) {
        phase = .preview(plan)
        self.executor = executor
    }

    var activePlan: ChangePlan {
        switch phase {
        case .preview(let plan), .applying(let plan):
            plan
        case .result(let report):
            report.sourcePlan
        }
    }

    var isApplying: Bool {
        if case .applying = phase {
            return true
        }
        return false
    }

    var hasExecuted: Bool {
        if case .result = phase {
            return true
        }
        return false
    }

    var canRetry: Bool {
        guard case .result(let report) = phase else {
            return false
        }
        return report.results.contains {
            $0.status != .verified
        }
    }

    func confirm() async {
        guard case .preview(let plan) = phase else {
            return
        }
        phase = .applying(plan)
        phase = .result(await executor.execute(plan))
    }

    func retryFailures() async {
        guard case .result(let report) = phase else {
            return
        }
        let plan = report.retryPlan()
        guard !plan.changes.isEmpty else {
            return
        }
        phase = .applying(plan)
        phase = .result(await executor.execute(plan))
    }

    func diagnostics() -> String? {
        guard case .result(let report) = phase else {
            return nil
        }

        return report.results.map { result in
            let error = result.errorDescription.map {
                " | \($0)"
            } ?? ""
            return [
                result.change.association.stableKey,
                result.status.rawValue
            ]
            .joined(separator: " | ") + error
        }
        .joined(separator: "\n")
    }
}

struct ChangeConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ChangeSheetModel
    @State private var didRefresh = false

    private let descriptors: [String: AssociationDescriptor]
    private let onRefresh: () -> Void

    init(
        plan: ChangePlan,
        executor: ChangeExecutor,
        catalog: AssociationCatalog,
        onRefresh: @escaping () -> Void
    ) {
        _model = StateObject(
            wrappedValue: ChangeSheetModel(
                plan: plan,
                executor: executor
            )
        )
        descriptors = Dictionary(
            catalog.snapshot().map { ($0.id, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        self.onRefresh = onRefresh
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider()
            phaseContent
            Divider()
            footer
        }
        .frame(width: 660, height: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .interactiveDismissDisabled(model.isApplying)
        .onDisappear {
            refreshIfNeeded()
        }
    }

    private var sheetHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: headerSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(headerTint)
                .frame(width: 38, height: 38)
                .background(
                    headerTint.opacity(0.12),
                    in: RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(headerTitle)
                    .font(.title2.weight(.bold))
                Text(headerSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)
        }
        .padding(22)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .preview(let plan):
            changeList(
                plan: plan,
                results: nil,
                isApplying: false
            )
        case .applying(let plan):
            changeList(
                plan: plan,
                results: nil,
                isApplying: true
            )
        case .result(let report):
            changeList(
                plan: report.sourcePlan,
                results: Dictionary(
                    report.results.map { ($0.id, $0) },
                    uniquingKeysWith: { current, _ in current }
                ),
                isApplying: false
            )
        }
    }

    private func changeList(
        plan: ChangePlan,
        results: [String: ChangeItemResult]?,
        isApplying: Bool
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                applicationTransition(plan: plan)

                if plan.changes.contains(
                    where: {
                        $0.compatibility == .manuallySelected
                    }
                ) {
                    warning(
                        titleKey: "change.compatibilityWarning.title",
                        messageKey:
                            "change.compatibilityWarning.message"
                    )
                }

                if isApplying {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("change.applyingProgress")
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("change.atomicChanges")
                        .font(.headline)

                    ForEach(plan.changes) { change in
                        AtomicChangeRow(
                            change: change,
                            descriptor: descriptors[
                                change.association.stableKey
                            ],
                            result: results?[change.id],
                            isApplying: isApplying
                        )
                    }
                }

                warning(
                    titleKey: "change.systemConsent.title",
                    messageKey: "change.systemConsent.message"
                )
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func applicationTransition(
        plan: ChangePlan
    ) -> some View {
        GlassCard {
            HStack(spacing: 18) {
                applicationSummary(
                    applications: previousApplications(in: plan),
                    fallbackKey: "change.noPreviousApplication"
                )

                Image(systemName: "arrow.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
                    .accessibilityLabel(
                        Text("change.transitionAccessibility")
                    )

                applicationSummary(
                    applications: targetApplications(in: plan),
                    fallbackKey: "change.noTargetApplication"
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func applicationSummary(
        applications: [HandlerApplication],
        fallbackKey: String
    ) -> some View {
        VStack(spacing: 8) {
            if let application = applications.first {
                ZStack {
                    ForEach(
                        Array(applications.prefix(3).enumerated()),
                        id: \.element.stableID
                    ) { index, item in
                        ApplicationIconView(
                            application: item,
                            size: 52
                        )
                        .offset(x: CGFloat(index) * 11)
                    }
                }
                .frame(
                    width: 52 + CGFloat(
                        max(0, min(applications.count, 3) - 1)
                    ) * 11,
                    height: 52
                )

                Group {
                    if applications.count == 1 {
                        Text(application.displayName)
                    } else {
                        Text("change.multipleApplications")
                    }
                }
                .font(.body.weight(.medium))
                .lineLimit(1)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(fallbackKey))
                    .font(.body.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func warning(
        titleKey: String,
        messageKey: String
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(titleKey))
                    .font(.callout.weight(.semibold))
                Text(LocalizedStringKey(messageKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.orange.opacity(0.09),
            in: RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .preview:
                Spacer()
                Button("action.cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("change.confirmAction") {
                    Task {
                        await model.confirm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("change.confirm")

            case .applying:
                ProgressView()
                    .controlSize(.small)
                Text("change.pleaseWait")
                    .foregroundStyle(.secondary)
                Spacer()

            case .result:
                Button {
                    copyDiagnostics()
                } label: {
                    Label(
                        "change.copyDiagnostics",
                        systemImage: "doc.on.doc"
                    )
                }
                .buttonStyle(.borderless)

                Spacer()

                if model.canRetry {
                    Button("change.retryFailures") {
                        Task {
                            await model.retryFailures()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(
                        "change.retryFailures"
                    )
                }

                Button("change.complete") {
                    refreshIfNeeded()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var headerTitle: LocalizedStringKey {
        switch model.phase {
        case .preview:
            "change.confirmTitle"
        case .applying:
            "change.applyingTitle"
        case .result(let report):
            report.results.allSatisfy {
                $0.status == .verified
            }
                ? "change.successTitle"
                : "change.partialTitle"
        }
    }

    private var headerSubtitle: LocalizedStringKey {
        switch model.phase {
        case .preview:
            "change.confirmSubtitle"
        case .applying:
            "change.applyingSubtitle"
        case .result(let report):
            report.results.allSatisfy {
                $0.status == .verified
            }
                ? "change.successSubtitle"
                : "change.partialSubtitle"
        }
    }

    private var headerSymbol: String {
        switch model.phase {
        case .preview:
            "checklist"
        case .applying:
            "arrow.triangle.2.circlepath"
        case .result(let report):
            report.results.allSatisfy {
                $0.status == .verified
            }
                ? "checkmark.circle.fill"
                : "exclamationmark.circle.fill"
        }
    }

    private var headerTint: Color {
        switch model.phase {
        case .preview, .applying:
            .blue
        case .result(let report):
            report.results.allSatisfy {
                $0.status == .verified
            }
                ? .green
                : .orange
        }
    }

    private func previousApplications(
        in plan: ChangePlan
    ) -> [HandlerApplication] {
        uniqueApplications(
            plan.changes.compactMap(\.previousHandler)
        )
    }

    private func targetApplications(
        in plan: ChangePlan
    ) -> [HandlerApplication] {
        uniqueApplications(
            plan.changes.map(\.targetHandler)
        )
    }

    private func uniqueApplications(
        _ applications: [HandlerApplication]
    ) -> [HandlerApplication] {
        Dictionary(
            applications.map { ($0.stableID, $0) },
            uniquingKeysWith: { current, _ in current }
        )
        .values
        .sorted {
            $0.displayName.localizedStandardCompare($1.displayName)
                == .orderedAscending
        }
    }

    private func copyDiagnostics() {
        guard let diagnostics = model.diagnostics() else {
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            diagnostics,
            forType: .string
        )
    }

    private func refreshIfNeeded() {
        guard model.hasExecuted, !didRefresh else {
            return
        }
        didRefresh = true
        onRefresh()
    }
}

private struct AtomicChangeRow: View {
    let change: PlannedChange
    let descriptor: AssociationDescriptor?
    let result: ChangeItemResult?
    let isApplying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                statusIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        LocalizedStringKey(
                            descriptor?.localizationKey
                                ?? identifier
                        )
                    )
                    .font(.body.weight(.medium))

                    Text(identifier)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 12)

                if let result {
                    Text(
                        LocalizedStringKey(
                            statusKey(result.status)
                        )
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusTint(result.status))
                } else if isApplying {
                    Text("change.status.applying")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("change.status.pending")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !explanatoryTags.isEmpty {
                HStack(spacing: 6) {
                    Text("change.explanatoryTags")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    ForEach(explanatoryTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Color.secondary.opacity(0.1),
                                in: Capsule()
                            )
                    }
                }
                .padding(.leading, 31)
            }
        }
        .padding(12)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(
                cornerRadius: 11,
                style: .continuous
            )
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if let result {
            Image(systemName: statusSymbol(result.status))
                .foregroundStyle(statusTint(result.status))
                .frame(width: 20)
                .accessibilityHidden(true)
        } else if isApplying {
            ProgressView()
                .controlSize(.small)
                .frame(width: 20)
        } else {
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
    }

    private var identifier: String {
        switch change.association {
        case .contentType(let identifier):
            identifier
        case .urlScheme(let scheme):
            scheme
        }
    }

    private var explanatoryTags: [String] {
        guard let descriptor else {
            return []
        }
        return descriptor.filenameExtensions.map { ".\($0)" }
            + descriptor.mimeTypes
    }

    private func statusKey(
        _ status: ChangeItemResult.Status
    ) -> String {
        "change.status.\(status.rawValue)"
    }

    private func statusSymbol(
        _ status: ChangeItemResult.Status
    ) -> String {
        switch status {
        case .verified:
            "checkmark.circle.fill"
        case .failed:
            "xmark.circle.fill"
        case .notApplied:
            "exclamationmark.circle.fill"
        }
    }

    private func statusTint(
        _ status: ChangeItemResult.Status
    ) -> Color {
        switch status {
        case .verified:
            .green
        case .failed:
            .red
        case .notApplied:
            .orange
        }
    }
}
