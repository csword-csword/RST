import SwiftData
import SwiftUI

/// Workout builder: compose reusable workouts from an equipment catalog —
/// the standard list or a chain-specific one (Planet Fitness, LA Fitness).
struct TemplatesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.catalogStore) private var catalogStore
    @AppStorage("gymProfileID") private var gymProfileID = "standard"
    @Query(sort: \WorkoutTemplate.createdAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("No workouts built", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Build a workout from your gym's equipment list, then start it from Home.")
                    } actions: {
                        Button("New Workout") { createTemplate() }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                    }
                } else {
                    List {
                        ForEach(templates) { template in
                            NavigationLink(value: template) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                    Text("\(catalogStore.catalog(id: template.gymProfileID).name) · \(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Builder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { createTemplate() } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: WorkoutTemplate.self) { template in
                TemplateEditorView(template: template)
            }
        }
    }

    private func createTemplate() {
        let template = WorkoutTemplate(name: "New Workout", gymProfileID: gymProfileID)
        modelContext.insert(template)
        path.append(template)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
    }
}
