import SwiftUI
import SwiftData
import Charts

private struct ExerciseSessionStats: Identifiable {
    let id: String
    let date: Date
    let sets: [RepeatItem]

    var setCount: Int {
        sets.count
    }

    var maxWeight: Double? {
        sets.compactMap(\.weight).max()
    }

    var maxValue: Double {
        sets.map(\.value).max() ?? 0
    }

    var totalValue: Double {
        sets.reduce(0) { $0 + $1.value }
    }

    var volume: Double {
        sets.reduce(0) { result, repeatItem in
            result + repeatItem.value * (repeatItem.weight ?? 1)
        }
    }
}

struct ExerciseDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumStore: PremiumStore

    let exercise: ExerciseItem

    @State private var isDeleteConfirmationPresented = false

    private var sessionStats: [ExerciseSessionStats] {
        Dictionary(grouping: exercise.repeats, by: \.createdAt)
            .compactMap { createdAt, repeats in
                guard let date = date(from: createdAt) else {
                    return nil
                }

                return ExerciseSessionStats(
                    id: createdAt,
                    date: date,
                    sets: repeats.sorted { $0.id.uuidString < $1.id.uuidString }
                )
            }
            .sorted { $0.date < $1.date }
    }

    private var recordWeight: Double? {
        exercise.repeats.compactMap(\.weight).max()
    }

    private var recordValue: Double? {
        exercise.repeats.map(\.value).max()
    }

    private var totalSets: Int {
        exercise.repeats.count
    }

    private var totalProgressTitle: String {
        switch exercise.type {
        case .distance:
            "Total distance"
        case .time:
            "Total time"
        case .repeats:
            "Total volume"
        }
    }

    private var totalProgressValue: String {
        switch exercise.type {
        case .distance:
            return "\(exercise.repeats.reduce(0) { $0 + $1.value }.formatted(.number.precision(.fractionLength(0...2)))) km"
        case .time:
            return "\(exercise.repeats.reduce(0) { $0 + $1.value }.formatted(.number.precision(.fractionLength(0...2)))) min"
        case .repeats:
            let volume = exercise.repeats.reduce(0) { $0 + $1.value * ($1.weight ?? 1) }
            return "\(volume.formatted(.number.precision(.fractionLength(0...2)))) kg reps"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerPanel

                if !premiumStore.isPremium {
                    PremiumRequiredState(
                        title: "Premium Exercise Stats",
                        message: "Upgrade to unlock this exercise's sessions, records, and progress charts.",
                        systemImage: "chart.bar.xaxis"
                    )
                } else if exercise.repeats.isEmpty {
                    emptyStatsPanel
                } else {
                    summaryPanel
                    chartsPanel
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .appGlassBackground()
        .navigationTitle(exercise.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button {
                        exercise.isFavorite.toggle()
                        saveContext()
                    } label: {
                        Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(exercise.isFavorite ? "Remove From Favorites" : "Add To Favorites")

                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete Exercise")
                }
            }
        }
        .alert("Delete Exercise?", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteExercise()
            }
        } message: {
            Text("This exercise will be removed from storage.")
        }
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.type.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(exercise.name)
                .font(.title.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .liquidPanel()
    }

    private var emptyStatsPanel: some View {
        ContentUnavailableView(
            "No Statistics",
            systemImage: "chart.xyaxis.line",
            description: Text("Complete this exercise in a workout to build progress charts.")
        )
        .liquidPanel()
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stats", systemImage: "chart.bar.xaxis")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(title: "Sessions", value: "\(sessionStats.count)")
                statTile(title: "Sets", value: "\(totalSets)")

                if exercise.type == .repeats {
                    statTile(title: "Record weight", value: formattedWeight(recordWeight))
                    statTile(title: totalProgressTitle, value: totalProgressValue)
                } else {
                    statTile(title: "Best set", value: formattedValue(recordValue ?? 0, type: exercise.type))
                    statTile(title: totalProgressTitle, value: totalProgressValue)
                }
            }
        }
        .liquidPanel()
    }

    private var chartsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Progress", systemImage: "chart.xyaxis.line")
                .font(.headline)

            if exercise.type == .repeats {
                chartSection(
                    title: "Weight Progress",
                    systemImage: "scalemass",
                    emptyText: "No weighted sets yet."
                ) {
                    weightChart
                }
            }

            chartSection(title: "Sets Per Workout", systemImage: "list.number") {
                setsChart
            }

            chartSection(title: "Overall Progress", systemImage: "arrow.up.forward") {
                overallProgressChart
            }
        }
        .liquidPanel()
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private func chartSection<Content: View>(
        title: String,
        systemImage: String,
        emptyText: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let emptyText, weightedSessions.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    }
            } else {
                content()
                    .frame(height: 170)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    }
            }
        }
    }

    private var weightedSessions: [ExerciseSessionStats] {
        sessionStats.filter { $0.maxWeight != nil }
    }

    private var weightChart: some View {
        Chart(weightedSessions) { session in
            if let maxWeight = session.maxWeight {
                LineMark(
                    x: .value("Date", session.date),
                    y: .value("Weight", maxWeight)
                )
                .foregroundStyle(Color.accentColor)

                PointMark(
                    x: .value("Date", session.date),
                    y: .value("Weight", maxWeight)
                )
                .foregroundStyle(Color.accentColor)
            }
        }
        .chartYAxisLabel("kg")
    }

    private var setsChart: some View {
        Chart(sessionStats) { session in
            BarMark(
                x: .value("Date", session.date),
                y: .value("Sets", session.setCount)
            )
            .foregroundStyle(Color.accentColor)
        }
    }

    private var overallProgressChart: some View {
        Chart(sessionStats) { session in
            LineMark(
                x: .value("Date", session.date),
                y: .value("Progress", progressValue(for: session))
            )
            .foregroundStyle(Color.accentColor)

            AreaMark(
                x: .value("Date", session.date),
                y: .value("Progress", progressValue(for: session))
            )
            .foregroundStyle(Color.accentColor.opacity(0.18))
        }
    }

    private func deleteExercise() {
        let exerciseID = exercise.id

        for repeatItem in exercise.repeats {
            modelContext.delete(repeatItem)
        }

        deleteWorkoutExerciseLinks(for: exerciseID)
        deleteGoals(for: exerciseID)
        modelContext.delete(exercise)

        saveAndDismiss()
    }

    private func deleteWorkoutExerciseLinks(for exerciseID: UUID) {
        do {
            let workouts = try modelContext.fetch(FetchDescriptor<WorkoutItem>())

            for workout in workouts {
                let deletedExerciseItems = workout.exerciseItems.filter { $0.exerciseID == exerciseID }

                guard !deletedExerciseItems.isEmpty else {
                    continue
                }

                for exerciseItem in deletedExerciseItems {
                    modelContext.delete(exerciseItem)
                }

                workout.exerciseItems.removeAll { exerciseItem in
                    deletedExerciseItems.contains { $0.id == exerciseItem.id }
                }

                for (index, exerciseItem) in workout.exerciseItems
                    .sorted(by: { $0.sortOrder < $1.sortOrder })
                    .enumerated() {
                    exerciseItem.sortOrder = index
                }
            }
        } catch {
            assertionFailure("Failed to clean workout exercise links: \(error)")
        }
    }

    private func deleteGoals(for exerciseID: UUID) {
        do {
            let goals = try modelContext.fetch(FetchDescriptor<GoalItem>())

            for goal in goals where goal.exerciseID == exerciseID {
                modelContext.delete(goal)
            }
        } catch {
            assertionFailure("Failed to clean exercise goals: \(error)")
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save exercise: \(error)")
        }
    }

    private func saveAndDismiss() {
        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to delete exercise: \(error)")
        }
    }

    private func progressValue(for session: ExerciseSessionStats) -> Double {
        switch exercise.type {
        case .distance, .time:
            return session.totalValue
        case .repeats:
            return session.volume
        }
    }

    private func formattedValue(_ value: Double, type: RepeatType) -> String {
        let formattedValue = value.formatted(.number.precision(.fractionLength(0...2)))

        switch type {
        case .distance:
            return "\(formattedValue) km"
        case .time:
            return "\(formattedValue) min"
        case .repeats:
            return "\(formattedValue) reps"
        }
    }

    private func formattedWeight(_ weight: Double?) -> String {
        guard let weight else {
            return "-"
        }

        return "\(weight.formatted(.number.precision(.fractionLength(0...2)))) kg"
    }

    private func date(from dateString: String) -> Date? {
        ISO8601DateFormatter().date(from: dateString)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetails(
            exercise: ExerciseItem(
                name: "Squat",
                type: .repeats,
                repeats: []
            )
        )
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
