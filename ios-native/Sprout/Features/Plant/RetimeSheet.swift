import SwiftUI

/// Дата записи в журнале поливов — из меню записи «Изменить дату…». Выбор
/// только за последние девяносто дней и не в будущем; «Отмена» ничего не
/// меняет, «Готово» переносит запись.
struct RetimeSheet: View {
    let plantID: Plant.ID
    let moment: Date

    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = Date()
    @State private var refused = false

    private let now = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("Когда полили", selection: $date,
                           in: now.addingTimeInterval(-90 * 86_400)...now,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(Palette.accent)
                if refused {
                    Text("Рядом другой полив — или дата вне девяноста дней.")
                        .font(Typography.settingNote)
                        .foregroundStyle(Palette.warn)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.blurReplace)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 8)
            .navigationTitle("Дата полива")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { save() }
                }
            }
        }
        .onAppear { date = moment }
    }

    private func save() {
        guard garden.retime(Watering(plant: plantID, when: moment), to: date)
        else {
            withAnimation(Motion.enter) { refused = true }
            return
        }
        Feel.toss()
        dismiss()
    }
}
