import ImagePlayground
import PhotosUI
import SwiftUI

/// «Изменить» в профиле: фото, имя и цвет кружка — одним листом, а не
/// окошком с одним полем. Фото и цвет встают сразу, имя — по «Готово» или
/// когда лист смахнули.
struct ProfileEditor: View {
    @Environment(Garden.self) private var garden
    @Environment(\.dismiss) private var dismiss

    private let settings = Settings.shared

    @State private var name = ""

    /// Фото хозяина, выбранное в медиатеке.
    @State private var picking: PhotosPickerItem?

    @State private var swatches = Spots()

    /// «Портрет» — только там, где есть Image Playground.
    @Environment(\.supportsImagePlayground) private var playground

    @State private var portraying = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.groupGap) {
                    face
                    SproutGroup("Имя") {
                        TextField("Как вас зовут?", text: $name)
                            .font(Typography.detail)
                            .textContentType(.name)
                            .submitLabel(.done)
                            .onSubmit(save)
                        Text("Имя стоит в профиле и уходит вместе со счётом друзьям.")
                            .font(Typography.settingNote)
                            .foregroundStyle(.secondary)
                    }
                    // Цвет — кружку без фото; с фото выбирать нечего.
                    if settings.avatarShot == nil {
                        SproutGroup("Цвет") {
                            // Волны отсюда нет нарочно: кружок хозяина не
                            // красит ни узор, ни всплеск.
                            HueRow(current: settings.avatarHue, layer: .avatar,
                                   spots: swatches,
                                   pick: { hue, _ in
                                       settings.avatarHue = hue
                                       Feel.pick()
                                   },
                                   remove: { colour, _ in
                                       settings.remove(own: colour,
                                                       from: .avatar)
                                       Feel.toss()
                                   })
                        }
                        .transition(.blurReplace)
                    }
                }
                .padding(.horizontal, Metrics.contentMargin)
                .padding(.vertical, 16)
                .animation(Motion.appear, value: settings.avatarShot)
            }
            .background { SproutBackground() }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .sproutSettledEdge()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        save()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { name = garden.owner }
        .onDisappear(perform: save)
        .onChange(of: picking) { _, item in
            Task { await portrait(item) }
        }
        // Готовая картинка встаёт в кружок, как выбранное фото.
        .imagePlaygroundSheet(isPresented: $portraying, concepts: concepts,
                              sourceImage: likeness) { file in
            guard let image = UIImage(contentsOfFile: file.path) else { return }
            try? FileManager.default.removeItem(at: file)
            wear(image)
        }
    }

    /// С фото — портрет по нему; без фото — по имени, см. `Portrait`.
    private var concepts: [ImagePlaygroundConcept] {
        Portrait.concepts(owner: name, photo: settings.avatarShot != nil)
            .map { ImagePlaygroundConcept.text($0) }
    }

    private var likeness: Image? {
        settings.avatarShot.flatMap { Snapshot.image($0) }
            .map { Image(uiImage: $0) }
    }

    /// Крупный кружок, кнопки фото под ним и «Портрет» отдельным рядом: в
    /// один ряд три кнопки не влезали.
    private var face: some View {
        VStack(spacing: 14) {
            AvatarCircle(size: Metrics.avatar * 1.6)
            HStack(spacing: 10) {
                PhotosPicker(selection: $picking, matching: .images,
                             photoLibrary: .shared()) {
                    Label(settings.avatarShot == nil ? "Выбрать фото"
                                                     : "Другое фото",
                          systemImage: "photo")
                        .lineLimit(1)
                }
                .buttonStyle(.glass)
                if settings.avatarShot != nil {
                    Button(role: .destructive, action: unportrait) {
                        Label("Убрать фото", systemImage: "trash")
                            .lineLimit(1)
                    }
                    .buttonStyle(.glass)
                    .transition(.blurReplace)
                }
            }
            .font(Typography.settingNote)
            if playground {
                Button { portraying = true } label: {
                    Label("Портрет", systemImage: "apple.image.playground")
                        .lineLimit(1)
                }
                .buttonStyle(.glass)
                .font(Typography.settingNote)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Имя — как вписали, без пробелов по краям. То же — и не трогаем.
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != garden.owner else { return }
        garden.rename(owner: trimmed)
        Feel.done()
    }

    @MainActor
    private func portrait(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return }
        wear(image)
        picking = nil
    }

    /// Квадрат из середины снимка, ужатый, — в папку снимков; прежнее фото
    /// уходит с диска.
    private func wear(_ image: UIImage) {
        let width = Double(image.size.width)
        let height = Double(image.size.height)
        let side = min(width, height)
        let square = Snapshot.cut(image, to: Crop(x: (width - side) / 2,
                                                  y: (height - side) / 2,
                                                  side: side))
        guard let name = Snapshot.keep(square) else { return }
        let old = settings.avatarShot
        settings.avatarShot = name
        if let old { Shots.drop(old) }
        Feel.done()
    }

    private func unportrait() {
        guard let old = settings.avatarShot else { return }
        settings.avatarShot = nil
        Shots.drop(old)
        Feel.toss()
    }
}

/// Кружок хозяина: фото во весь круг; без фото — буква или человечек на
/// цвете хозяина.
struct AvatarCircle: View {
    let size: CGFloat

    @Environment(Garden.self) private var garden

    private let settings = Settings.shared

    var body: some View {
        if let name = settings.avatarShot, let image = Snapshot.image(name) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .transition(.blurReplace)
        } else {
            Circle()
                .fill(Palette.swatch(settings.avatarHue))
                .frame(width: size, height: size)
                .overlay {
                    // Неназвавшемуся — значок человека: пустой кружок
                    // читался бы недогрузившейся картинкой.
                    Group {
                        if garden.owner.isEmpty {
                            Image(systemName: "person.fill")
                        } else {
                            Text(letter)
                        }
                    }
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .transition(.blurReplace)
        }
    }

    private var letter: String {
        String(garden.owner.trimmingCharacters(in: .whitespaces)
            .prefix(1)).uppercased(with: Locale.current)
    }
}
