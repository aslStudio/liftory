import SwiftUI
import SwiftData
import Combine

private struct WorkoutSessionSet: Identifiable {
    let id = UUID()
    let value: Double
    let weight: Double?
}

private enum WorkoutSessionField: Hashable {
    case repeatValue(UUID)
    case weight(UUID)
}

struct WorkoutSession: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let workout: WorkoutItem
    let scheduledWorkout: ScheduledWorkoutItem?

    @State private var currentExerciseIndex = 0
    @State private var startedAt = Date()
    @State private var elapsedSeconds = 0
    @State private var repeatValues: [UUID: String] = [:]
    @State private var weightValues: [UUID: String] = [:]
    @State private var pendingRepeats: [UUID: [WorkoutSessionSet]] = [:]
    @State private var isFinishConfirmationPresented = false
    @FocusState private var focusedField: WorkoutSessionField?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var exercises: [ExerciseItem] {
        workout.orderedExercises
    }

    private var currentExercise: ExerciseItem? {
        guard exercises.indices.contains(currentExerciseIndex) else {
            return nil
        }

        return exercises[currentExerciseIndex]
    }

    private var currentRepeatValue: Binding<String> {
        Binding {
            guard let currentExercise else {
                return ""
            }

            return repeatValues[currentExercise.id, default: ""]
        } set: { value in
            guard let currentExercise else {
                return
            }

            repeatValues[currentExercise.id] = value
        }
    }

    private var currentWeightValue: Binding<String> {
        Binding {
            guard let currentExercise else {
                return ""
            }

            return weightValues[currentExercise.id, default: ""]
        } set: { value in
            guard let currentExercise else {
                return
            }

            weightValues[currentExercise.id] = value
        }
    }

    private var canAddRepeat: Bool {
        repeatValue(from: currentRepeatValue.wrappedValue) != nil && optionalWeight(from: currentWeightValue.wrappedValue) != .invalid
    }

    var body: some View {
        ZStack {
            AppGlassBackground()

            ScrollView {
                VStack(spacing: 18) {
                    timerHeader

                    if let currentExercise {
                        exerciseInput(for: currentExercise)
                    } else {
                        ContentUnavailableView(
                            "No Exercises",
                            systemImage: "dumbbell",
                            description: Text("This workout does not contain exercises.")
                        )
                        .liquidPanel()
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            navigationControls
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Finish") {
                    isFinishConfirmationPresented = true
                }
                .disabled(exercises.isEmpty)
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .onReceive(timer) { now in
            elapsedSeconds = max(0, Int(now.timeIntervalSince(startedAt)))
        }
        .alert("Finish Workout?", isPresented: $isFinishConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Finish", role: .destructive) {
                finishWorkout()
            }
        } message: {
            Text("Workout duration and entered sets will be saved.")
        }
    }

    private var timerHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Workout Time", systemImage: "timer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(min(currentExerciseIndex + 1, max(exercises.count, 1)))/\(max(exercises.count, 1))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(.thinMaterial)
                    }
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(formattedDuration(elapsedSeconds))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer()
            }

            progressBar
        }
        .liquidPanel()
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            let total = max(exercises.count - 1, 1)
            let progress = exercises.count <= 1 ? 1 : Double(currentExerciseIndex) / Double(total)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 8)
    }

    private func exerciseInput(for exercise: ExerciseItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background {
                        Circle()
                            .fill(.thinMaterial)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Exercise \(currentExerciseIndex + 1) of \(exercises.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(exercise.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text(exercise.type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background {
                        Capsule()
                            .fill(.thinMaterial)
                    }
            }

            VStack(spacing: 10) {
                TextField(valuePlaceholder(for: exercise.type), text: currentRepeatValue)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .repeatValue(exercise.id))
                    .font(.title3.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.26), lineWidth: 1)
                            }
                    }

                if exercise.type == .repeats {
                    TextField("Weight (optional)", text: currentWeightValue)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight(exercise.id))
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.regularMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.white.opacity(0.26), lineWidth: 1)
                                }
                        }
                }
            }

            Button {
                addRepeat(for: exercise)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
            .disabled(!canAddRepeat)

            currentSetsSection(for: exercise)

            previousSetsSection(for: exercise)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidPanel()
    }

    private func currentSetsSection(for exercise: ExerciseItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Sets", systemImage: "list.bullet.rectangle")
                    .font(.headline)

                Spacer()

                Text("\(pendingRepeats[exercise.id, default: []].count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            let repeats = pendingRepeats[exercise.id, default: []]

            if repeats.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle")
                    Text("No sets entered yet.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.thinMaterial)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(repeats.enumerated()), id: \.element.id) { index, set in
                        setRow(
                            number: index + 1,
                            value: formattedRepeatValue(set.value, weight: set.weight, type: exercise.type)
                        )
                    }
                }
            }
        }
    }

    private func previousSetsSection(for exercise: ExerciseItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Previous Workout", systemImage: "clock.arrow.circlepath")
                    .font(.headline)

                Spacer()

                if let date = previousWorkoutDate(for: exercise) {
                    Text(formattedDate(date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let previousSets = previousWorkoutSets(for: exercise)

            if previousSets.isEmpty {
                Text("No previous sets.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(previousSets.enumerated()), id: \.element.id) { index, repeatItem in
                        setRow(
                            number: index + 1,
                            value: formattedRepeatValue(repeatItem.value, weight: repeatItem.weight, type: repeatItem.type)
                        )
                    }
                }
            }
        }
    }

    private func setRow(number: Int, value: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(.regularMaterial)
                }

            Text("Set")
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private var navigationControls: some View {
        HStack(spacing: 12) {
            Button {
                moveToPreviousExercise()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glass)
            .disabled(currentExerciseIndex == 0)

            Button {
                moveToNextExercise()
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
            .disabled(currentExerciseIndex >= exercises.count - 1)
        }
        .padding(10)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private func addRepeat(for exercise: ExerciseItem) {
        guard let value = repeatValue(from: repeatValues[exercise.id, default: ""]) else {
            return
        }

        guard optionalWeight(from: weightValues[exercise.id, default: ""]) != .invalid else {
            return
        }

        pendingRepeats[exercise.id, default: []].append(
            WorkoutSessionSet(
                value: value,
                weight: weightValue(for: exercise)
            )
        )
        repeatValues[exercise.id] = ""
        weightValues[exercise.id] = ""
    }

    private func moveToPreviousExercise() {
        guard currentExerciseIndex > 0 else {
            return
        }

        currentExerciseIndex -= 1
    }

    private func moveToNextExercise() {
        guard currentExerciseIndex < exercises.count - 1 else {
            return
        }

        currentExerciseIndex += 1
    }

    private func finishWorkout() {
        for exercise in exercises {
            if let value = repeatValue(from: repeatValues[exercise.id, default: ""]) {
                guard optionalWeight(from: weightValues[exercise.id, default: ""]) != .invalid else {
                    continue
                }

                pendingRepeats[exercise.id, default: []].append(
                    WorkoutSessionSet(
                        value: value,
                        weight: weightValue(for: exercise)
                    )
                )
                repeatValues[exercise.id] = ""
                weightValues[exercise.id] = ""
            }
        }

        workout.durations.append(elapsedSeconds)
        scheduledWorkout?.completedWeekID = ScheduleCalendar.currentWeekID()
        let completedAt = ISO8601DateFormatter().string(from: Date())

        for exercise in exercises {
            let values = pendingRepeats[exercise.id, default: []]

            for set in values {
                let repeatItem = RepeatItem(
                    type: exercise.type,
                    value: set.value,
                    weight: set.weight,
                    createdAt: completedAt
                )

                modelContext.insert(repeatItem)
                exercise.repeats.append(repeatItem)
            }
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to finish workout: \(error)")
        }
    }

    private func repeatValue(from text: String) -> Double? {
        let normalizedText = text.replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalizedText), value > 0 else {
            return nil
        }

        return value
    }

    private enum OptionalWeightParseResult: Equatable {
        case value(Double)
        case empty
        case invalid
    }

    private func optionalWeight(from text: String) -> OptionalWeightParseResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return .empty
        }

        let normalizedText = trimmedText.replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalizedText), value > 0 else {
            return .invalid
        }

        return .value(value)
    }

    private func weightValue(for exercise: ExerciseItem) -> Double? {
        guard exercise.type == .repeats else {
            return nil
        }

        switch optionalWeight(from: weightValues[exercise.id, default: ""]) {
        case .value(let value):
            return value
        case .empty, .invalid:
            return nil
        }
    }

    private func previousWorkoutSets(for exercise: ExerciseItem) -> [RepeatItem] {
        guard let latestCreatedAt = exercise.repeats.map(\.createdAt).max() else {
            return []
        }

        return exercise.repeats
            .filter { $0.createdAt == latestCreatedAt }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func previousWorkoutDate(for exercise: ExerciseItem) -> Date? {
        guard let latestCreatedAt = exercise.repeats.map(\.createdAt).max() else {
            return nil
        }

        return ISO8601DateFormatter().date(from: latestCreatedAt)
    }

    private func valuePlaceholder(for type: RepeatType) -> String {
        switch type {
        case .distance:
            "Distance"
        case .time:
            "Time"
        case .repeats:
            "Repeats"
        }
    }

    private func formattedRepeatValue(_ value: Double, weight: Double?, type: RepeatType) -> String {
        let formattedValue = value.formatted(.number.precision(.fractionLength(0...2)))

        switch type {
        case .distance:
            return "\(formattedValue) km"
        case .time:
            return "\(formattedValue) min"
        case .repeats:
            if let weight {
                let formattedWeight = weight.formatted(.number.precision(.fractionLength(0...2)))
                return "\(formattedValue) reps · \(formattedWeight) kg"
            }

            return "\(formattedValue) reps"
        }
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let seconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

}

#Preview {
    let exercise = ExerciseItem(
        name: "Squat",
        type: .repeats,
        repeats: []
    )

    let workout = WorkoutItem(
        name: "Leg Day",
        durations: [],
        exerciseItems: [
            WorkoutExerciseItem(exercise: exercise, sortOrder: 0)
        ]
    )

    NavigationStack {
        WorkoutSession(workout: workout, scheduledWorkout: nil)
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
