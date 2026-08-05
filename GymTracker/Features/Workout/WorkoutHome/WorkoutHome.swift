import SwiftUI
import SwiftData

private enum Section: String, CaseIterable, Identifiable {
    case workout = "Workout"
    case exercises = "Exercises"

    var id: Self { self }
}

struct WorkoutHome: View {
    @State private var selectedSection: Section = .workout

    var body: some View {
        VStack(spacing: 16) {
            Picker("Section", selection: $selectedSection) {
                ForEach(Section.allCases) { section in
                    Text(section.rawValue)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedSection == .workout {
                WorkoutListSection()
            } else {
                ExerciseListSection()
            }
        }
        .appGlassBackground()
        .navigationTitle(selectedSection == .workout ? "Workout" : "Exercises")
    }
}

private struct WorkoutListSection: View {
    @EnvironmentObject private var premiumStore: PremiumStore

    @Query(sort: \WorkoutItem.name) private var workouts: [WorkoutItem]

    @State private var isPaywallPresented = false

    private var canCreateWorkout: Bool {
        premiumStore.isPremium || workouts.count < 3
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if canCreateWorkout {
                    NavigationLink {
                        CreateWorkout()
                    } label: {
                        Text("Create Workout")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.glassProminent)
                } else {
                    Button {
                        isPaywallPresented = true
                    } label: {
                        Label("Unlock Unlimited Workouts", systemImage: "crown.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.glassProminent)
                }

                if !premiumStore.isPremium {
                    Text("\(min(workouts.count, 3))/3 workouts included")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("Created workouts will appear here.")
                    )
                    .liquidPanel()
                    .padding(.top, 16)
                } else {
                    ForEach(workouts) { workout in
                        NavigationLink {
                            WorkoutDetails(workout: workout)
                        } label: {
                            WorkoutCard(workout: workout)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $isPaywallPresented) {
            NavigationStack {
                PremiumPaywall()
            }
        }
    }
}

private struct ExerciseListSection: View {
    @Query(sort: \ExerciseItem.name) private var exercises: [ExerciseItem]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink {
                    CreateExercise()
                } label: {
                    Text("Create Exercise")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.glassProminent)

                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "dumbbell",
                        description: Text("Created exercises will appear here.")
                    )
                    .liquidPanel()
                    .padding(.top, 16)
                } else {
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            ExerciseDetails(exercise: exercise)
                        } label: {
                            ExerciseCard(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct WorkoutCard: View {
    let workout: WorkoutItem

    var body: some View {
        HStack(spacing: 12) {
            Text(workout.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .liquidCard()
    }
}

struct ExerciseCard: View {
    let exercise: ExerciseItem

    var body: some View {
        HStack(spacing: 12) {
            Text(exercise.name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .liquidCard()
    }
}

#Preview {
    NavigationStack {
        WorkoutHome()
    }
    .modelContainer(for: [ExerciseItem.self, WorkoutItem.self, WorkoutExerciseItem.self, RepeatItem.self, GoalItem.self, ScheduledWorkoutItem.self], inMemory: true)
}
