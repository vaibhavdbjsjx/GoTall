#if os(iOS)
import SwiftUI
import GrowthCore
import DesignSystem

struct HabitsView: View {
    let repository: AppRepository
    @State private var editing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let profile = repository.activeProfile {
                        let state = DashboardBuilder(now: Date(), calendar: .current).build(for: profile)
                        HabitBaselineSection(habits: state.habits)
                        AppButton("Update starting points", systemImage: "slider.horizontal.3", kind: .secondary) { editing = true }
                    }
                    EmptyStateView(
                        systemImage: "checklist",
                        title: "Daily check-ins are on the way",
                        message: "Soon you'll be able to log sleep, activity, eating and posture in a few taps and see how routines change."
                    )
                    .dsSurface()
                }
                .padding(.horizontal, DS.Spacing.page)
                .padding(.vertical, DS.Spacing.md)
            }
            .dsPageBackground()
            .navigationTitle("Habits")
            .toolbar { ToolbarItem(placement: .topBarLeading) { ProfileSwitcher(repository: repository) } }
            .sheet(isPresented: $editing) {
                if let profile = repository.activeProfile {
                    EditProfileView(repository: repository, profile: profile, focus: .lifestyle)
                }
            }
        }
    }
}
#endif
