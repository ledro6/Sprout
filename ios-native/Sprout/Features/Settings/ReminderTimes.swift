import SwiftUI

/// Под переключателем «Напоминать о поливе»: во сколько приходит утреннее
/// напоминание и когда тихие часы. Всё остальное — правила `Plan`: одно
/// утреннее, не больше двух уведомлений в день.
struct ReminderTimes: View {
    private let settings = Settings.shared

    /// Уведомления разрешены в телефоне. Отозвать разрешение могли там, и
    /// приложению об этом не скажут.
    @State private var allowed = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !allowed {
                AccessNote(need: .notifications)
            }
            row(Lang.text("Утреннее напоминание"), time: Binding(
                get: { settings.morning }, set: { settings.morning = $0 }))
            row(Lang.text("Тихие часы с"), time: Binding(
                get: { settings.quietFrom }, set: { settings.quietFrom = $0 }))
            row(Lang.text("Тихие часы до"), time: Binding(
                get: { settings.quietTo }, set: { settings.quietTo = $0 }))
            Text("Приходит одно напоминание в день и только когда есть кого полить; всего не больше двух уведомлений в день.")
                .font(Typography.settingNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task { allowed = await Notifier.allowed() }
    }

    private func row(_ title: String,
                     time: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 8)
            DatePicker(title, selection: Self.date(time),
                       displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    /// Минуты от полуночи — как время суток для выбора.
    static func date(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60,
                                      minute: minutes.wrappedValue % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { picked in
                let parts = Calendar.current.dateComponents([.hour, .minute],
                                                            from: picked)
                minutes.wrappedValue = (parts.hour ?? 0) * 60
                    + (parts.minute ?? 0)
            })
    }
}
