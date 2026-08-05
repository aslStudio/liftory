import SwiftUI
import SwiftData
import Charts

private struct FavoriteExerciseProgress: Identifiable {
    let id: String
    let exerciseName: String
    let date: Date
    let value: Double
}

private enum FavoriteChartKind {
    case weight
    case time
    case distance

    var title: String {
        switch self {
        case .weight:
            "Weight"
        case .time:
            "Time"
        case .distance:
            "Distance"
        }
    }

    var systemImage: String {
        switch self {
        case .weight:
            "scalemass"
        case .time:
            "timer"
        case .distance:
            "figure.run"
        }
    }

    var yAxisLabel: String {
        switch self {
        case .weight:
            "kg"
        case .time:
            "min"
        case .distance:
            "km"
        }
    }
}

struct StatisticsHome: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumStore: PremiumStore

    @Query(sort: \ExerciseItem.name) private var exercises: [ExerciseItem]
    @Query(sort: \GoalItem.createdAt, order: .reverse) private var goals: [GoalItem]

    @State private var isGoalFormPresented = false

    private var favoriteExercises: [ExerciseItem] {
        exercises.filter(\.isFavorite)
    }

    var body: some View {
        Group {
            if premiumStore.isPremium {
                ScrollView {
                    VStack(spacing: 16) {
                        overviewPanel
                        favoritesPanel
                        goalsPanel
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            isGoalFormPresented = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Goal")
                    }
                }
            } else {
                ScrollView {
                    PremiumRequiredState(
                        title: "Premium Statistics",
                        message: "Upgrade to see progress charts, goals, favorite exercise trends, and detailed workout analytics.",
                        systemImage: "chart.xyaxis.line"
                    )
                    .padding()
                }
                .scrollContentBackground(.hidden)
            }
        }
        .appGlassBackground()
        .navigationTitle("Statistics")
        .sheet(isPresented: $isGoalFormPresented) {
            NavigationStack {
                GoalForm()
            }
        }
    }

    private var overviewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overview", systemImage: "chart.pie")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(title: "Exercises", value: "\(exercises.count)")
                statTile(title: "Favorites", value: "\(favoriteExercises.count)")
                statTile(title: "Goals", value: "\(goals.count)")
                statTile(title: "Completed", value: "\(goals.filter(\.isCompleted).count)")
            }
        }
        .liquidPanel()
    }

    private var favoritesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Favorite Exercises", systemImage: "star.fill")
                .font(.headline)

            if favoriteExercises.isEmpty {
                Text("Mark exercises as favorites to track them here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if favoriteProgressPoints(for: .weight).isEmpty
                        && favoriteProgressPoints(for: .time).isEmpty
                        && favoriteProgressPoints(for: .distance).isEmpty {
                Text("Complete favorite exercises in workouts to build charts.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                favoriteChart(kind: .weight)
                favoriteChart(kind: .time)
                favoriteChart(kind: .distance)
            }
        }
        .liquidPanel()
    }

    private var goalsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Goals", systemImage: "target")
                    .font(.headline)

                Spacer()

                Button {
                    isGoalFormPresented = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Add Goal")
            }

            if goals.isEmpty {
                Text("Create goals like max bench press weight and track progress here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(goals) { goal in
                        goalRow(goal)
                    }
                }
            }
        }
        .liquidPanel()
    }

    private func goalRow(_ goal: GoalItem) -> some View {
        let currentValue = currentValue(for: goal)
        let progress = goal.targetValue > 0 ? min(currentValue / goal.targetValue, 1) : 0
        let exerciseName = goal.exerciseID.flatMap { exerciseID in
            exercises.first { $0.id == exerciseID }?.name
        } ?? "Any exercise"

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.body.weight(.semibold))

                    Text(exerciseName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    goal.isCompleted.toggle()
                    saveContext()
                } label: {
                    Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: progress)
                .tint(Color.accentColor)

            HStack {
                Text(goal.metric.title)
                Spacer()
                Text("\(formattedNumber(currentValue)) / \(formattedNumber(goal.targetValue))")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private func currentValue(for goal: GoalItem) -> Double {
        let repeats: [RepeatItem]

        if let exerciseID = goal.exerciseID,
           let exercise = exercises.first(where: { $0.id == exerciseID }) {
            repeats = exercise.repeats
        } else {
            repeats = exercises.flatMap(\.repeats)
        }

        switch goal.metric {
        case .maxWeight:
            return repeats.compactMap(\.weight).max() ?? 0
        case .totalSets:
            return Double(repeats.count)
        case .totalVolume:
            return repeats.reduce(0) { $0 + $1.value * ($1.weight ?? 1) }
        }
    }

    private func favoriteChart(kind: FavoriteChartKind) -> some View {
        let points = favoriteProgressPoints(for: kind)

        return VStack(alignment: .leading, spacing: 10) {
            Label(kind.title, systemImage: kind.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if points.isEmpty {
                Text(emptyFavoriteChartText(for: kind))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    }
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(kind.title, point.value),
                        series: .value("Exercise", point.exerciseName)
                    )
                    .foregroundStyle(by: .value("Exercise", point.exerciseName))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(kind.title, point.value)
                    )
                    .foregroundStyle(by: .value("Exercise", point.exerciseName))
                }
                .chartYAxisLabel(kind.yAxisLabel)
                .frame(height: 190)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                }
            }
        }
    }

    private func favoriteProgressPoints(for kind: FavoriteChartKind) -> [FavoriteExerciseProgress] {
        favoriteExercises
            .filter { exercise in
                switch kind {
                case .weight:
                    exercise.type == .repeats
                case .time:
                    exercise.type == .time
                case .distance:
                    exercise.type == .distance
                }
            }
            .flatMap { exercise in
                Dictionary(grouping: exercise.repeats, by: \.createdAt)
                    .compactMap { createdAt, repeats in
                        guard let date = ISO8601DateFormatter().date(from: createdAt),
                              let value = favoriteProgressValue(for: repeats, kind: kind) else {
                            return nil
                        }

                        return FavoriteExerciseProgress(
                            id: "\(exercise.id.uuidString)-\(createdAt)-\(kind.title)",
                            exerciseName: exercise.name,
                            date: date,
                            value: value
                        )
                    }
            }
            .sorted { $0.date < $1.date }
    }

    private func favoriteProgressValue(for repeats: [RepeatItem], kind: FavoriteChartKind) -> Double? {
        switch kind {
        case .weight:
            return repeats.compactMap(\.weight).max()
        case .time, .distance:
            let value = repeats.reduce(0) { $0 + $1.value }
            return value > 0 ? value : nil
        }
    }

    private func emptyFavoriteChartText(for kind: FavoriteChartKind) -> String {
        switch kind {
        case .weight:
            "Favorite repeat exercises with recorded weight will appear here."
        case .time:
            "Favorite time exercises will appear here."
        case .distance:
            "Favorite distance exercises will appear here."
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save statistics changes: \(error)")
        }
    }
}

private struct GoalForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExerciseItem.name) private var exercises: [ExerciseItem]

    @State private var title = ""
    @State private var metric: GoalMetric = .maxWeight
    @State private var targetValue = ""
    @State private var selectedExerciseID: UUID?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedTargetValue: Double? {
        let normalizedText = targetValue.replacingOccurrences(of: ",", with: ".")
        return Double(normalizedText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        Form {
            Section {
                TextField("Goal title", text: $title)

                Picker("Metric", selection: $metric) {
                    ForEach(GoalMetric.allCases) { metric in
                        Text(metric.title)
                            .tag(metric)
                    }
                }

                TextField("Target", text: $targetValue)
                    .keyboardType(.decimalPad)
            }

            Section("Exercise") {
                Picker("Exercise", selection: $selectedExerciseID) {
                    Text("Any exercise")
                        .tag(UUID?.none)

                    ForEach(exercises) { exercise in
                        Text(exercise.name)
                            .tag(UUID?.some(exercise.id))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background {
            AppGlassBackground()
        }
        .navigationTitle("Add Goal")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveGoal()
                }
                .disabled(trimmedTitle.isEmpty || parsedTargetValue == nil)
            }
        }
    }

    private func saveGoal() {
        guard let parsedTargetValue else {
            return
        }

        let exercise = selectedExerciseID.flatMap { selectedExerciseID in
            exercises.first { $0.id == selectedExerciseID }
        }

        let goal = GoalItem(
            title: trimmedTitle,
            exerciseID: exercise?.id,
            exercise: exercise,
            metric: metric,
            targetValue: parsedTargetValue,
            createdAt: ISO8601DateFormatter().string(from: Date())
        )

        modelContext.insert(goal)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to save goal: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsHome()
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
