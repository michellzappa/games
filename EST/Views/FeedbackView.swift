import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var replyEmail = ""
    @State private var phase: Phase = .idle

    private enum Phase {
        case idle
        case sending
        case sent
        case failed(String)
    }

    private var trimmedMessage: String {
        ESTFeedbackService.normalizedMessage(message)
    }

    private var isSending: Bool {
        if case .sending = phase { return true }
        return false
    }

    private var isSent: Bool {
        if case .sent = phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .disabled(isSending || isSent)

                    HStack {
                        Text("Your message")
                        Spacer()
                        Text("\(message.count)/\(ESTFeedbackService.maxMessageLength)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.caption)
                } header: {
                    Text("Tell us what you think")
                } footer: {
                    Text("This is sent to mz@centaur-labs.io via the EST feedback service. Do not include sensitive information.")
                }

                Section {
                    TextField("you@example.com", text: $replyEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(isSending || isSent)
                } header: {
                    Text("Email (optional)")
                } footer: {
                    Text("Add your email only if you want a reply. Leave it empty and the message stays anonymous.")
                }

                if case .failed(let message) = phase {
                    Section {
                        Label(message, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }

                if isSent {
                    Section {
                        Label("Feedback sent. Thank you.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(GameAccent.second.color)
                    }
                } else {
                    Section {
                        Button {
                            send()
                        } label: {
                            HStack {
                                Spacer()
                                if isSending {
                                    ProgressView()
                                        .padding(.trailing, 6)
                                    Text("Sending…")
                                } else {
                                    Text("Send feedback")
                                }
                                Spacer()
                            }
                        }
                        .disabled(trimmedMessage.isEmpty || isSending)
                    }
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Appearance.shared.gameBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: message) { _, newValue in
                if newValue.count > ESTFeedbackService.maxMessageLength {
                    message = String(newValue.prefix(ESTFeedbackService.maxMessageLength))
                }
                if isSent {
                    phase = .idle
                }
            }
        }
    }

    private func send() {
        let message = trimmedMessage
        guard !message.isEmpty else {
            phase = .failed("Write a message before sending feedback.")
            return
        }

        // Validate the address before showing the sending state, so a typo
        // reads as a correction rather than a delivery failure.
        do {
            _ = try ESTFeedbackService.normalizedEmail(replyEmail)
        } catch {
            phase = .failed(error.localizedDescription)
            return
        }

        phase = .sending
        Task {
            do {
                try await ESTFeedbackService.send(
                    message: message, replyEmail: replyEmail)
                phase = .sent
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    FeedbackView()
}
