import SwiftUI

/// Подтверждение того, что не вернуть: красная кнопка оживает, только когда
/// введено слово или число из подсказки. Случайным нажатием сад не стереть.
struct TypedConfirm: View {
    /// «Стереть сад?»
    let title: String
    /// Что исчезнет и у кого.
    let message: String
    /// «Введите 18, чтобы стереть».
    let prompt: String
    /// Что ввести — без учёта регистра и пробелов по краям.
    let answer: String
    /// Красная кнопка: «Стереть», «Удалить».
    let done: String
    var numeric = false
    let confirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""
    @FocusState private var focused: Bool

    private var matches: Bool {
        typed.trimmingCharacters(in: .whitespacesAndNewlines)
            .compare(answer, options: [.caseInsensitive, .diacriticInsensitive])
            == .orderedSame
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(message)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField(prompt, text: $typed)
                        .keyboardType(numeric ? .numberPad : .default)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                }
                Section {
                    Button(role: .destructive) {
                        confirm()
                        dismiss()
                    } label: {
                        Text(done)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!matches)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("Erase, light") {
    TypedConfirm(title: "Стереть сад?",
                 message: "Исчезнут все растения и весь журнал поливов. Вернуть их будет нельзя.",
                 prompt: "Введите 18, чтобы стереть", answer: "18",
                 done: "Стереть", numeric: true) {}
}

#Preview("Erase, dark") {
    TypedConfirm(title: "Стереть сад?",
                 message: "Исчезнут все растения и весь журнал поливов. Вернуть их будет нельзя.",
                 prompt: "Введите 18, чтобы стереть", answer: "18",
                 done: "Стереть", numeric: true) {}
        .preferredColorScheme(.dark)
}
