import SwiftUI

/// «Спросить сад»: вопрос обычными словами — ответ языковой модели Apple
/// прямо на телефоне, без сети, потоком. Открывается с экрана растения —
/// тогда разговор о нём, — из «ещё» на главной и из поиска, который ничего
/// не нашёл. Без модели на языке приложения (`Muse.ready`) входов нет.
struct AskView: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    @State private var talk: Talk

    @State private var draft: String

    /// `draft` — вопрос, с которым пришли: из поиска он уже набран.
    init(focus: Plant.ID? = nil, draft: String = "") {
        _talk = State(initialValue: Talk(focus: focus))
        _draft = State(initialValue: draft)
    }

    private var plant: Plant? { talk.focus.flatMap { garden.plant(id: $0) } }

    /// О растении листа, а открыт лист не с растения — о самом сухом.
    private var prompts: [String] {
        Sage.prompts(about: plant ?? Sage.example(in: garden.rooms))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.rowGap) {
                    if let plant {
                        about(plant)
                    }
                    if talk.lines.isEmpty {
                        intro
                            .transition(.blurReplace)
                    }
                    ForEach(talk.lines) { line in
                        bubble(line)
                            .transition(.blurReplace)
                    }
                    if talk.busy, talk.lines.last?.text.isEmpty == true {
                        thinking
                            .transition(.blurReplace)
                    }
                    if let trouble = talk.trouble {
                        problem(trouble)
                            .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.top, 4)
                .padding(.bottom, 16)
                .animation(Motion.enter, value: talk.lines.count)
                .animation(Motion.enter, value: talk.busy)
                .animation(Motion.enter, value: talk.trouble)
            }
            // Как в «Сообщениях»: разговор растёт снизу, у поля ввода.
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .background { SproutBackground() }
            .safeAreaInset(edge: .bottom) { composer }
            .navigationTitle("Спросить сад")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(Motion.enter) { talk.reset() }
                        Feel.toss()
                    } label: {
                        Label("Новый разговор", systemImage: "square.and.pencil")
                    }
                    .disabled(talk.lines.isEmpty && talk.trouble == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        // Лист закрыли посреди ответа — модель дальше не пишет.
        .onDisappear { talk.stop() }
    }

    /// О ком разговор — кличкой и видом над ним.
    private func about(_ plant: Plant) -> some View {
        HStack(spacing: 12) {
            PlantPhoto(plant: plant, radius: 12)
                .frame(width: Metrics.navCircle, height: Metrics.navCircle)
                .clipShape(RoundedRectangle(cornerRadius: 12,
                                            style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(plant.name)
                    .font(Typography.detail)
                    .foregroundStyle(Palette.ink)
                Text(plant.species)
                    .font(Typography.settingNote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 6)
    }

    /// Пока не спросили: что это и вопросы-подсказки кнопками.
    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Спросите о саде своими словами — ответит языковая модель прямо на телефоне, без интернета.")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
            ForEach(prompts, id: \.self) { prompt in
                Button { ask(prompt) } label: {
                    Text(prompt)
                        .font(Typography.settingRow)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle(radius: Metrics.toolRadius))
            }
            Text("Модель может ошибаться. Если растение болеет, покажите его на снимке: «Что с ним?» на экране растения.")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 6)
        }
    }

    /// Вопрос — справа, синим стеклом; ответ — слева, плашкой, как совет в
    /// «Что с ним?».
    @ViewBuilder
    private func bubble(_ line: Talk.Line) -> some View {
        if line.asked {
            Text(line.text)
                .font(Typography.settingRow)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(Palette.accent),
                             in: .rect(cornerRadius: Metrics.toolRadius))
                .padding(.leading, 48)
                .frame(maxWidth: .infinity, alignment: .trailing)
        } else if !line.text.isEmpty {
            Text(Self.rich(line.text))
                .font(Typography.settingRow)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(Metrics.groupPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sproutPlate(in: RoundedRectangle(
                    cornerRadius: Metrics.cardRadius, style: .continuous))
                .padding(.trailing, 24)
        }
    }

    private var thinking: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text("Думаю…")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
    }

    /// Не вышло — почему; кончилось окно модели — сразу и выход.
    private func problem(_ trouble: Talk.Trouble) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(trouble.text, systemImage: "exclamationmark.bubble")
                .font(Typography.settingNote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if trouble == .long {
                Button {
                    withAnimation(Motion.enter) { talk.reset() }
                } label: {
                    Label("Новый разговор", systemImage: "square.and.pencil")
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }
        }
        .padding(.horizontal, 6)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Спросите о саде…", text: $draft)
                .font(Typography.settingRow)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(Typography.detail)
                    .frame(width: Metrics.gearBox, height: Metrics.gearBox)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .disabled(talk.busy || Sage.question(draft) == nil)
            .accessibilityLabel("Спросить")
        }
        .padding(.horizontal, Metrics.contentMargin)
        .padding(.vertical, 8)
    }

    private func send() {
        guard !talk.busy, let question = Sage.question(draft) else { return }
        draft = ""
        ask(question)
    }

    private func ask(_ question: String) {
        withAnimation(Motion.enter) { talk.ask(question) }
        Feel.pick()
    }

    /// Жирное и курсив модели — как задумано; прочая разметка — текстом.
    private static func rich(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options))
            ?? AttributedString(text)
    }
}
