import SwiftUI

enum Nav {
    static let today = "__today__"
    static let chat = "__chat__"
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showingNew = false

    private var listSelection: Binding<String?> {
        Binding(
            get: { state.selection ?? Nav.today },
            set: { state.selection = ($0 == Nav.today || $0 == nil) ? nil : $0 }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: listSelection) {
                Label("Today", systemImage: "sun.max.fill")
                    .tag(Nav.today)

                Label("Assistant", systemImage: "sparkles")
                    .tag(Nav.chat)

                Section("Habits") {
                    ForEach(state.habits) { habit in
                        SidebarRow(habit: habit)
                            .tag(habit.id)
                    }
                    .onMove { state.moveHabits(fromOffsets: $0, toOffset: $1) }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Health")
            .frame(minWidth: 220)
            .toolbar {
                ToolbarItem {
                    Button { showingNew = true } label: {
                        Label("New Habit", systemImage: "plus")
                    }
                    .help("New habit")
                }
            }
        } detail: {
            Group {
                if state.selection == Nav.chat {
                    ChatView(vm: state.chat)
                } else if let id = state.selection, let habit = state.habits.first(where: { $0.id == id }) {
                    HabitDetailView(habit: habit)
                } else {
                    TodayView()
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewHabitView()
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { state.errorMessage != nil },
                                    set: { if !$0 { state.errorMessage = nil } })) {
            Button("OK", role: .cancel) { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
    }
}

/// A sidebar row: icon + name + a small status dot reflecting today's logging.
struct SidebarRow: View {
    @EnvironmentObject var state: AppState
    let habit: Habit

    var body: some View {
        Label {
            Text(habit.name)
        } icon: {
            Image(systemName: habit.icon)
                .foregroundStyle(Color(hex: habit.color))
        }
        .badge(badgeText)
    }

    private var badgeText: Text? {
        let logged = !state.todayEntries(for: habit).isEmpty
        return logged ? Text(Image(systemName: "checkmark")) : nil
    }
}
