#if os(iOS)
import CompHuntKit
import EventKit
import EventKitUI
import SwiftUI

/// Staged by the "Add to Calendar" menu action (`CompetitionActions`);
/// MainWindow watches it and presents the system event-edit sheet. A singleton
/// because the actions menu renders in two places (detail header, row context
/// menu) and neither owns a presentation surface.
@MainActor
@Observable
final class EventEditRequest {
    static let shared = EventEditRequest()
    var competition: Competition?
}

extension View {
    /// Attach once near the window root: presents the event-edit sheet whenever
    /// an actions menu stages a competition.
    func eventEditSheet() -> some View {
        modifier(EventEditSheetModifier())
    }
}

private struct EventEditSheetModifier: ViewModifier {
    @State private var request = EventEditRequest.shared

    func body(content: Content) -> some View {
        content.sheet(item: Bindable(request).competition) { competition in
            EventEditView(competition: competition)
                .ignoresSafeArea()
        }
    }
}

/// The system EKEventEditViewController, pre-filled from the shared
/// `CalendarEventPlan` (the same shape the macOS .ics export and the EventKit
/// sync use). Since iOS 17 EventKitUI runs out of process and needs no calendar
/// permission; the user confirms inside the sheet itself.
private struct EventEditView: UIViewControllerRepresentable {
    let competition: Competition

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let controller = EKEventEditViewController()
        controller.eventStore = store
        if let plan = CalendarEventPlan.plan(for: competition) {
            let event = EKEvent(eventStore: store)
            event.title = plan.title
            event.startDate = plan.start
            event.endDate = plan.end
            event.notes = plan.notes
            event.url = URL(string: plan.url)
            if !plan.location.isEmpty {
                event.location = plan.location
            }
            event.addAlarm(EKAlarm(relativeOffset: plan.alarmOffset))
            controller.event = event
        }
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator { dismiss() }
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency EKEventEditViewDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onFinish()
        }
    }
}
#endif
