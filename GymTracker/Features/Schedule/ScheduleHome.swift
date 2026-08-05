import SwiftUI
import SwiftData

struct ScheduleHome: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutItem.name) private var workouts: [WorkoutItem]
    @Query(sort: \ScheduledWorkoutItem.createdAt) private var scheduledWorkouts: [ScheduledWorkoutItem]

    @State private var selectedDayForAdd: Weekday?

    private var currentWeekID: String {
        ScheduleCalendar.currentWeekID()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                todayPanel
                weekPanel
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .appGlassBackground()
        .navigationTitle("Schedule")
        .sheet(item: $selectedDayForAdd) { day in
            NavigationStack {
                AddScheduledWorkout(day: day)
            }
        }
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today", systemImage: "calendar.circle.fill")
                .font(.headline)

            let todayItems = scheduledItems(for: .today)

            if todayItems.isEmpty {
                Text("No workouts scheduled for today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(todayItems) { scheduledWorkout in
                        scheduledWorkoutRow(scheduledWorkout, showDay: false)
                    }
                }
            }
        }
        .liquidPanel()
    }

    private var weekPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Week", systemImage: "calendar")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(Weekday.weekOrder) { day in
                    daySection(day)
                }
            }
        }
        .liquidPanel()
    }

    private func daySection(_ day: Weekday) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.title)
                        .font(.body.weight(.semibold))

                    Text("\(scheduledItems(for: day).count) workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    selectedDayForAdd = day
                } label: {
                    Image(systemName: workouts.isEmpty ? "plus" : "checklist")
                }
                .buttonStyle(.glass)
                .accessibilityLabel(workouts.isEmpty ? "Create Workout" : "Edit Day Workouts")
            }

            let dayItems = scheduledItems(for: day)

            if dayItems.isEmpty {
                Text(workouts.isEmpty ? "Create workouts before scheduling." : "No workouts scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.thinMaterial)
                    }
            } else {
                VStack(spacing: 8) {
                    ForEach(dayItems) { scheduledWorkout in
                        scheduledWorkoutRow(scheduledWorkout, showDay: false)
                    }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private func scheduledWorkoutRow(_ scheduledWorkout: ScheduledWorkoutItem, showDay: Bool) -> some View {
        let isCompleted = scheduledWorkout.completedWeekID == currentWeekID
        let workout = workout(for: scheduledWorkout)

        return HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isCompleted ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout?.name ?? "Deleted Workout")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(showDay ? scheduledWorkout.day.title : (isCompleted ? "Completed this week" : "Not completed"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let workout {
                NavigationLink {
                    WorkoutSession(workout: workout, scheduledWorkout: scheduledWorkout)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glassProminent)
                .disabled(workout.orderedExercises.isEmpty)
            }

            Button(role: .destructive) {
                deleteScheduledWorkout(scheduledWorkout)
            } label: {
                Image(systemName: "trash")
                    .font(.caption.weight(.bold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Remove Workout From Day")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private func scheduledItems(for day: Weekday) -> [ScheduledWorkoutItem] {
        scheduledWorkouts
            .filter { $0.day == day }
            .sorted { lhs, rhs in
                let lhsName = workout(for: lhs)?.name ?? ""
                let rhsName = workout(for: rhs)?.name ?? ""

                if lhsName == rhsName {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhsName < rhsName
            }
    }

    private func deleteScheduledWorkout(_ scheduledWorkout: ScheduledWorkoutItem) {
        modelContext.delete(scheduledWorkout)

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to delete scheduled workout: \(error)")
        }
    }

    private func workout(for scheduledWorkout: ScheduledWorkoutItem) -> WorkoutItem? {
        guard let workoutID = scheduledWorkout.workoutID else {
            return nil
        }

        return workouts.first { $0.id == workoutID }
    }
}

private struct AddScheduledWorkout: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutItem.name) private var workouts: [WorkoutItem]
    @Query(sort: \ScheduledWorkoutItem.createdAt) private var scheduledWorkouts: [ScheduledWorkoutItem]

    let day: Weekday

    var body: some View {
        Group {
            if workouts.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Create a workout before scheduling it.")
                    )
                    .liquidPanel()

                    NavigationLink {
                        CreateWorkout()
                    } label: {
                        Text("Create Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.glassProminent)
                }
                .padding()
                .appGlassBackground()
            } else {
                List {
                    Section {
                        ForEach(workouts) { workout in
                            Button {
                                toggleWorkout(workout)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isScheduled(workout) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(isScheduled(workout) ? Color.accentColor : .secondary)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(workout.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text("\(workout.orderedExercises.count) exercises")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(day.title)
                    } footer: {
                        Text("Each workout can be selected once per day.")
                    }
                }
                .scrollContentBackground(.hidden)
                .background {
                    AppGlassBackground()
                }
            }
        }
        .navigationTitle(workouts.isEmpty ? "Create Workout" : "Edit \(day.shortTitle)")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func isScheduled(_ workout: WorkoutItem) -> Bool {
        scheduledItem(for: workout) != nil
    }

    private func scheduledItem(for workout: WorkoutItem) -> ScheduledWorkoutItem? {
        scheduledWorkouts.first { scheduledWorkout in
            scheduledWorkout.day == day && scheduledWorkout.workoutID == workout.id
        }
    }

    private func toggleWorkout(_ workout: WorkoutItem) {
        if let scheduledWorkout = scheduledItem(for: workout) {
            modelContext.delete(scheduledWorkout)
        } else {
            modelContext.insert(
                ScheduledWorkoutItem(
                    day: day,
                    workoutID: workout.id,
                    workout: workout
                )
            )
        }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to update scheduled workout: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleHome()
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
