import SwiftUI
import SwiftData
import Charts

private enum WorkoutDetailsSection: String, CaseIterable, Identifiable {
    case exercises = "Exercises"
    case statistics = "Stats"

    var id: Self { self }
}

private struct WorkoutDurationPoint: Identifiable {
    let id: Int
    let session: Int
    let duration: Int
}

struct WorkoutDetails: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var premiumStore: PremiumStore

    let workout: WorkoutItem

    @State private var isDeleteConfirmationPresented = false
    @State private var selectedSection: WorkoutDetailsSection = .exercises

    private var durationPoints: [WorkoutDurationPoint] {
        workout.durations.enumerated().map { index, duration in
            WorkoutDurationPoint(id: index, session: index + 1, duration: duration)
        }
    }

    private var averageDuration: Int {
        guard !workout.durations.isEmpty else {
            return 0
        }

        return workout.durations.reduce(0, +) / workout.durations.count
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Section", selection: $selectedSection) {
                ForEach(WorkoutDetailsSection.allCases) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)

            if selectedSection == .exercises {
                exercisesSection
            } else if premiumStore.isPremium {
                statisticsSection
            } else {
                PremiumRequiredState(
                    title: "Premium Workout Stats",
                    message: "Upgrade to unlock workout sessions, duration trends, averages, and best results.",
                    systemImage: "timer"
                )
            }

            Spacer()

            NavigationLink {
                WorkoutSession(workout: workout, scheduledWorkout: nil)
            } label: {
                Text("Start Workout")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.glassProminent)
            .disabled(workout.orderedExercises.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .appGlassBackground()
        .navigationTitle(workout.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete Workout")

                    NavigationLink {
                        EditWorkout(workout: workout)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit Workout")
                }
            }
        }
        .alert("Delete Workout?", isPresented: $isDeleteConfirmationPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWorkout()
            }
        } message: {
            Text("This workout will be removed from storage.")
        }
    }

    private var exercisesSection: some View {
        ScrollView {
            if workout.orderedExercises.isEmpty {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "dumbbell",
                    description: Text("This workout does not contain exercises yet.")
                )
                .liquidPanel()
                .padding(.top, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(workout.exerciseItems.sorted { $0.sortOrder < $1.sortOrder }) { exerciseItem in
                        if let exercise = exerciseItem.exercise {
                            NavigationLink {
                                ExerciseDetails(exercise: exercise)
                            } label: {
                                ExerciseCard(exercise: exercise)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var statisticsSection: some View {
        ScrollView {
            VStack(spacing: 16) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statTile(title: "Sessions", value: "\(workout.durations.count)")
                    statTile(title: "Exercises", value: "\(workout.orderedExercises.count)")
                    statTile(title: "Average", value: formattedDuration(averageDuration))
                    statTile(title: "Best", value: formattedDuration(workout.durations.max() ?? 0))
                }
                .liquidPanel()

                VStack(alignment: .leading, spacing: 12) {
                    Label("Duration Progress", systemImage: "timer")
                        .font(.headline)

                    if durationPoints.isEmpty {
                        Text("Complete this workout to build duration stats.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Chart(durationPoints) { point in
                            LineMark(
                                x: .value("Session", point.session),
                                y: .value("Minutes", Double(point.duration) / 60)
                            )
                            .foregroundStyle(Color.accentColor)

                            PointMark(
                                x: .value("Session", point.session),
                                y: .value("Minutes", Double(point.duration) / 60)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                        .chartYAxisLabel("min")
                        .frame(height: 190)
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.thinMaterial)
                        }
                    }
                }
                .liquidPanel()
            }
            .padding(.bottom)
        }
        .scrollContentBackground(.hidden)
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
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

    private func deleteWorkout() {
        let workoutID = workout.id

        deleteScheduledItems(for: workoutID)

        for exerciseItem in workout.exerciseItems {
            modelContext.delete(exerciseItem)
        }

        modelContext.delete(workout)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            assertionFailure("Failed to delete workout: \(error)")
        }
    }

    private func deleteScheduledItems(for workoutID: UUID) {
        do {
            let scheduledWorkouts = try modelContext.fetch(FetchDescriptor<ScheduledWorkoutItem>())

            for scheduledWorkout in scheduledWorkouts where scheduledWorkout.workoutID == workoutID {
                modelContext.delete(scheduledWorkout)
            }
        } catch {
            assertionFailure("Failed to clean scheduled workouts: \(error)")
        }
    }
}
