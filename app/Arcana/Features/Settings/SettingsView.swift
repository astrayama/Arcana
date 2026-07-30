import SwiftUI

/// Settings — tucked behind the Today avatar, per wireframe 1b.
/// Reminders, account/sync, data, and about.
struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var reminderTime = Date()
    @State private var confirmErase = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profilePanel
                    remindersPanel
                    dataPanel
                    aboutPanel
                }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background {
                Arcana.CosmosBackground()
                StarfieldView(opacity: 0.3)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Arcana.Palette.purpleSoft)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(30)
        .onAppear {
            reminderTime = Calendar.current.date(
                from: DateComponents(hour: store.reminderHour, minute: store.reminderMinute)
            ) ?? Date()
        }
    }

    // MARK: Profile / sync

    private var profilePanel: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Arcana.Palette.purple, Arcana.Palette.blue],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(String(session.userEmail?.first.map(String.init)?.uppercased() ?? "A"))
                        .bodyFont(19, weight: .heavy)
                        .foregroundStyle(Color(hex: 0x120C1E))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(session.userEmail ?? "Local ledger")
                    .bodyFont(15, weight: .bold)
                    .foregroundStyle(Arcana.Palette.text)
                Text(session.state == .demo
                     ? "Not synced — add Supabase keys to enable sync"
                     : "Synced with your web account")
                    .bodyFont(12)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            Spacer()
            if session.state == .signedIn {
                Button {
                    Task {
                        await session.signOut()
                        dismiss()
                    }
                } label: {
                    Text("Sign out")
                        .bodyFont(12.5, weight: .bold)
                        .foregroundStyle(Arcana.Palette.purpleSoft)
                }
            }
        }
        .padding(16)
        .glass()
    }

    // MARK: Reminders

    private var remindersPanel: some View {
        VStack(spacing: 0) {
            Toggle("Daily reminder", isOn: Binding(
                get: { store.remindersEnabled },
                set: { enabled in
                    store.remindersEnabled = enabled
                    Task {
                        if enabled {
                            store.remindersEnabled = await NotificationService.requestAndSchedule(
                                hour: store.reminderHour, minute: store.reminderMinute
                            )
                        } else {
                            NotificationService.cancel()
                        }
                    }
                }
            ))
            .bodyFont(14, weight: .semibold)
            .foregroundStyle(Arcana.Palette.text)
            .tint(Arcana.Palette.purple)
            .padding(.horizontal, 16).padding(.vertical, 13)

            if store.remindersEnabled {
                Divider().overlay(Arcana.Palette.hairline).padding(.horizontal, 16)
                DatePicker("Remind me at", selection: Binding(
                    get: { reminderTime },
                    set: { newValue in
                        reminderTime = newValue
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        store.reminderHour = parts.hour ?? 21
                        store.reminderMinute = parts.minute ?? 0
                        Task {
                            await NotificationService.schedule(
                                hour: store.reminderHour, minute: store.reminderMinute
                            )
                        }
                    }
                ), displayedComponents: .hourAndMinute)
                .bodyFont(14, weight: .semibold)
                .foregroundStyle(Arcana.Palette.text)
                .tint(Arcana.Palette.purple)
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .glass()
    }

    // MARK: Data

    private var dataPanel: some View {
        VStack(spacing: 0) {
            Toggle("Sync to Cloud", isOn: Binding(
                get: { store.syncEnabled },
                set: { enabled in
                    store.syncEnabled = enabled
                }
            ))
            .bodyFont(14, weight: .semibold)
            .foregroundStyle(Arcana.Palette.text)
            .tint(Arcana.Palette.gold)
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider().background(Color(hex: 0x392D53))

            if session.state == .demo {
                Button {
                    confirmErase = true
                } label: {
                    HStack {
                        Label("Erase journal & start fresh", systemImage: "trash")
                            .bodyFont(14, weight: .semibold)
                            .foregroundStyle(.red.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .confirmationDialog(
                    "This clears every entry on this device and replays the first-entry walkthrough.",
                    isPresented: $confirmErase, titleVisibility: .visible
                ) {
                    Button("Erase everything", role: .destructive) {
                        store.eraseAllLocalData()
                        store.hasOnboarded = true   // stay in the app, just an empty ledger
                    }
                }
            } else {
                HStack {
                    Label("Entries sync automatically", systemImage: "arrow.triangle.2.circlepath")
                        .bodyFont(14, weight: .semibold)
                        .foregroundStyle(Arcana.Palette.muted)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
            }
        }
        .glass()
    }

    // MARK: About

    private var aboutPanel: some View {
        VStack(spacing: 6) {
            Text("☾")
                .font(.system(size: 26))
                .foregroundStyle(Arcana.Palette.purple)
            Text("Arcana")
                .displayFont(20)
                .foregroundStyle(Arcana.brandGradient)
            Text("A quiet ledger for your cards, spreads,\nand the patterns between them.")
                .bodyFont(12)
                .foregroundStyle(Arcana.Palette.muted)
                .multilineTextAlignment(.center)
            Text("v1.0.0")
                .bodyFont(11)
                .foregroundStyle(Arcana.Palette.faint)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glass()
    }
}
