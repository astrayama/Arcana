import SwiftUI
import AuthenticationServices

/// Onboarding — wireframe 2h. Three beats, all skippable:
/// 1. brand intro · 2. sign-in (Apple first, email fallback) · 3. reminder ask with context.
struct OnboardingFlow: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var store: AppStore

    @State private var page = 0

    var body: some View {
        ZStack {
            Arcana.CosmosBackground()
            StarfieldView(opacity: 0.55)

            TabView(selection: $page) {
                IntroPage(next: { withAnimation { page = 1 } })
                    .tag(0)
                SignInPage(next: { withAnimation { page = 2 } })
                    .tag(1)
                ReminderPage(finish: finish)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                Spacer()
                PageDots(count: 3, index: page)
                    .padding(.bottom, 18)
            }
            .allowsHitTesting(false)
        }
    }

    private func finish() {
        store.hasOnboarded = true
    }
}

// MARK: - Page dots

struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Arcana.Palette.purple : Color(hex: 0x4A4360))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Beat 1 · brand intro

private struct IntroPage: View {
    var next: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .strokeBorder(Arcana.Palette.purple.opacity(0.45),
                                  style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                    .frame(width: 130, height: 130)
                Text("☾")
                    .font(.system(size: 52))
                    .foregroundStyle(Arcana.Palette.purple)
                SparkleText(size: 14).offset(x: 44, y: -52)
                SparkleText(size: 10, delay: 1.2).offset(x: -52, y: 44)
            }

            Text("Arcana")
                .displayFont(40, weight: .medium)
                .foregroundStyle(Arcana.brandGradient)

            Text("A quiet ledger for your cards, spreads,\nand the patterns between them.")
                .bodyFont(14.5)
                .foregroundStyle(Arcana.Palette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()

            PurpleButton(title: "Begin", action: next)
                .padding(.horizontal, 24)
                .padding(.bottom, 60)
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Beat 2 · sign-in

private struct SignInPage: View {
    @EnvironmentObject private var session: SessionStore
    var next: () -> Void

    @State private var showEmailSheet = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Text("☾").font(.system(size: 40)).foregroundStyle(Arcana.Palette.purple)
            Text("Keep your ledger everywhere")
                .displayFont(28)
                .foregroundStyle(Arcana.Palette.text)
                .multilineTextAlignment(.center)
            Text("Sign in to sync with your existing web account.")
                .bodyFont(14)
                .foregroundStyle(Arcana.Palette.muted)

            Spacer()

            if session.state == .demo {
                // No Supabase credentials configured — run on the local ledger.
                GoldButton(title: "Continue — local ledger ✦") { next() }
                Text("Add Supabase keys in AppConfig.swift to enable sync & sign-in.")
                    .bodyFont(11.5)
                    .foregroundStyle(Arcana.Palette.faint)
                    .multilineTextAlignment(.center)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.email]
                } onCompletion: { result in
                    Task {
                        await session.signInWithApple(result: result)
                        if session.state == .signedIn { next() }
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                GlassButton(title: "Continue with email") { showEmailSheet = true }

                Text("syncs with your existing web account")
                    .bodyFont(11.5)
                    .foregroundStyle(Arcana.Palette.faint)
            }

            if let error = session.errorMessage {
                Text(error)
                    .bodyFont(12)
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 24)
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInSheet(onSignedIn: next)
                .presentationDetents([.medium])
                .presentationBackground(Color(hex: 0x13101E).opacity(0.98))
        }
    }
}

/// Email + password fallback for existing Supabase accounts.
private struct EmailSignInSheet: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    var onSignedIn: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isNewAccount = false
    @State private var busy = false

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(.white.opacity(0.25)).frame(width: 38, height: 5)
                .padding(.top, 10)

            Text(isNewAccount ? "Create account" : "Welcome back")
                .displayFont(24)
                .foregroundStyle(Arcana.Palette.text)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .glassField()
            SecureField("Password", text: $password)
                .textContentType(isNewAccount ? .newPassword : .password)
                .glassField()

            GoldButton(title: busy ? "…" : (isNewAccount ? "Create & sync" : "Sign in")) {
                guard !busy else { return }
                busy = true
                Task {
                    if isNewAccount {
                        await session.signUp(email: email, password: password)
                    } else {
                        await session.signIn(email: email, password: password)
                    }
                    busy = false
                    if session.state == .signedIn {
                        dismiss()
                        onSignedIn()
                    }
                }
            }

            Button {
                isNewAccount.toggle()
            } label: {
                Text(isNewAccount ? "I already have an account" : "New here? Create an account")
                    .bodyFont(13, weight: .semibold)
                    .foregroundStyle(Arcana.Palette.purpleSoft)
            }

            if let error = session.errorMessage {
                Text(error).bodyFont(12).foregroundStyle(.red.opacity(0.9))
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .foregroundStyle(Arcana.Palette.text)
    }
}

// MARK: - Beat 3 · reminder ask (with context, never at cold launch)

private struct ReminderPage: View {
    @EnvironmentObject private var store: AppStore
    var finish: () -> Void

    @State private var time = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            SparkleText(size: 44)

            Text("An evening nudge?")
                .displayFont(28)
                .foregroundStyle(Arcana.Palette.text)

            Text("One gentle reminder to pull your card —\nit's how streaks survive busy weeks.")
                .bodyFont(14.5)
                .foregroundStyle(Arcana.Palette.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Chip(label: "\(timeString) ⌄", isOn: true) {
                withAnimation(.snappy) { showPicker.toggle() }
            }
            .scaleEffect(1.15)
            .padding(.top, 4)

            if showPicker {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(.dark)
                    .frame(height: 120)
                    .clipped()
            }

            Spacer()

            GoldButton(title: "Allow reminders") {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                store.reminderHour = parts.hour ?? 21
                store.reminderMinute = parts.minute ?? 0
                Task {
                    store.remindersEnabled = await NotificationService.requestAndSchedule(
                        hour: store.reminderHour, minute: store.reminderMinute
                    )
                    finish()
                }
            }

            Button(action: finish) {
                Text("Maybe later")
                    .bodyFont(13, weight: .semibold)
                    .foregroundStyle(Arcana.Palette.muted)
            }
            .padding(.bottom, 60)
        }
        .padding(.horizontal, 24)
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}
