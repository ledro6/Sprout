package com.ledro6.sprout.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Виды, для которых в приложении есть готовая объёмная модель. Любой вид
 * сада сводится к ближайшему из них.
 */
@Serializable
enum class Preset {
    @SerialName("monstera") MONSTERA,
    @SerialName("ficus") FICUS,
    @SerialName("sansevieria") SANSEVIERIA,
    @SerialName("zamioculcas") ZAMIOCULCAS,
    @SerialName("spathiphyllum") SPATHIPHYLLUM,
    @SerialName("orchid") ORCHID,
    @SerialName("aloe") ALOE,
    @SerialName("cactus") CACTUS,
    @SerialName("echeveria") ECHEVERIA,
    @SerialName("jade") JADE,
    @SerialName("dracaena") DRACAENA,
    @SerialName("palm") PALM,
    @SerialName("fern") FERN,
    @SerialName("ivy") IVY,
    @SerialName("chlorophytum") CHLOROPHYTUM,
    @SerialName("violet") VIOLET,
    @SerialName("begonia") BEGONIA,
    @SerialName("pelargonium") PELARGONIUM,
    @SerialName("herbs") HERBS,
    @SerialName("tulip") TULIP,
    @SerialName("rose") ROSE,
    @SerialName("hoya") HOYA,
    @SerialName("mint") MINT,
    @SerialName("rosemary") ROSEMARY,
    @SerialName("kalanchoe") KALANCHOE,
    @SerialName("anthurium") ANTHURIUM,
    @SerialName("calathea") CALATHEA,
    @SerialName("pilea") PILEA,
    @SerialName("alocasia") ALOCASIA,
    @SerialName("lily") LILY,
    @SerialName("sunflower") SUNFLOWER,
    @SerialName("lavender") LAVENDER,
    @SerialName("citrus") CITRUS,
    @SerialName("haworthia") HAWORTHIA,
    @SerialName("opuntia") OPUNTIA,
    @SerialName("yucca") YUCCA,
    @SerialName("chrysanthemum") CHRYSANTHEMUM;

    /** Имя файла модели — как у готовых моделей iOS. */
    val raw: String get() = name.lowercase()

    val title: String
        get() = when (this) {
            MONSTERA -> Lang.text("Монстера")
            FICUS -> Lang.text("Фикус")
            SANSEVIERIA -> Lang.text("Сансевиерия")
            ZAMIOCULCAS -> Lang.text("Замиокулькас")
            SPATHIPHYLLUM -> Lang.text("Спатифиллум")
            ORCHID -> Lang.text("Орхидея")
            ALOE -> Lang.text("Алоэ")
            CACTUS -> Lang.text("Кактус")
            ECHEVERIA -> Lang.text("Эхеверия")
            JADE -> Lang.text("Толстянка")
            DRACAENA -> Lang.text("Драцена")
            PALM -> Lang.text("Пальма")
            FERN -> Lang.text("Папоротник")
            IVY -> Lang.text("Плющ")
            CHLOROPHYTUM -> Lang.text("Хлорофитум")
            VIOLET -> Lang.text("Фиалка")
            BEGONIA -> Lang.text("Бегония")
            PELARGONIUM -> Lang.text("Пеларгония")
            HERBS -> Lang.text("Пряные травы")
            TULIP -> Lang.text("Тюльпан")
            ROSE -> Lang.text("Роза")
            HOYA -> Lang.text("Хойя")
            MINT -> Lang.text("Мята")
            ROSEMARY -> Lang.text("Розмарин")
            KALANCHOE -> Lang.text("Каланхоэ")
            ANTHURIUM -> Lang.text("Антуриум")
            CALATHEA -> Lang.text("Калатея")
            PILEA -> Lang.text("Пилея")
            ALOCASIA -> Lang.text("Алоказия")
            LILY -> Lang.text("Лилия")
            SUNFLOWER -> Lang.text("Подсолнух")
            LAVENDER -> Lang.text("Лаванда")
            CITRUS -> Lang.text("Лимонное дерево")
            HAWORTHIA -> Lang.text("Хавортия")
            OPUNTIA -> Lang.text("Опунция")
            YUCCA -> Lang.text("Юкка")
            CHRYSANTHEMUM -> Lang.text("Хризантема")
        }

    companion object {
        /** По вписанному виду; не узнали — спатифиллум, как на iOS. */
        fun of(species: String): Preset = known(species) ?: SPATHIPHYLLUM

        /** Частное — раньше общего: «каменная роза» — суккулент, а не роза. */
        fun known(species: String): Preset? {
            val name = species.lowercase()
            return stem(name) ?: named().firstOrNull { name.contains(it.first) }?.second
        }

        private fun stem(name: String): Preset? =
            table.firstOrNull { name.contains(it.first) }?.second

        /** Названия моделей и видов на языке телефона; длинные раньше коротких. */
        private fun named(): List<Pair<String, Preset>> =
            (entries.map { it.title.lowercase() to it } +
                Species.table.mapNotNull { row ->
                    stem(row.species.lowercase())?.let { Lang.text(row.species).lowercase() to it }
                })
                .filter { it.first.length > 1 }
                .sortedByDescending { it.first.length }

        private val table: List<Pair<String, Preset>> = listOf(
            "монстер" to MONSTERA, "филодендрон" to MONSTERA,
            "фикус" to FICUS, "каучук" to FICUS, "деревце" to FICUS,
            "сансевиер" to SANSEVIERIA, "щучий" to SANSEVIERIA,
            "замиокулькас" to ZAMIOCULCAS, "долларов" to ZAMIOCULCAS,
            "спатифил" to SPATHIPHYLLUM, "диффенбах" to SPATHIPHYLLUM,
            "антуриум" to ANTHURIUM, "аглаонем" to SPATHIPHYLLUM,
            "орхиде" to ORCHID, "фаленопсис" to ORCHID,
            "алоказ" to ALOCASIA, "колоказ" to ALOCASIA,
            "алоэ" to ALOE, "хавортия" to HAWORTHIA, "гастери" to HAWORTHIA,
            "агав" to ALOE,
            "кактус" to CACTUS, "опунци" to OPUNTIA, "маммиллярия" to CACTUS,
            "эхевери" to ECHEVERIA, "суккулент" to ECHEVERIA,
            "молодил" to ECHEVERIA, "каменная роза" to ECHEVERIA,
            "толстянк" to JADE, "крассул" to JADE, "денежное" to JADE,
            "каланхоэ" to KALANCHOE,
            "драцен" to DRACAENA, "юкк" to YUCCA, "нолин" to YUCCA,
            "кордилин" to DRACAENA,
            "пальм" to PALM, "хамедоре" to PALM, "бамбук" to PALM,
            "папорот" to FERN, "нефролепис" to FERN, "мох" to FERN,
            "хойя" to HOYA, "плющ" to IVY, "сциндапсус" to IVY,
            "эпипремнум" to IVY, "традесканц" to IVY,
            "калате" to CALATHEA, "марант" to CALATHEA, "ктенант" to CALATHEA,
            "стромант" to CALATHEA,
            "пиле" to PILEA, "пеперомия" to PILEA,
            "пряност" to HERBS, "пряные" to HERBS,
            "хлорофит" to CHLOROPHYTUM, "трав" to CHLOROPHYTUM,
            "фиалк" to VIOLET, "сенполи" to VIOLET,
            "бегони" to BEGONIA,
            "пеларгони" to PELARGONIUM, "герань" to PELARGONIUM,
            "розмарин" to ROSEMARY,
            "роз" to ROSE, "хризантем" to CHRYSANTHEMUM,
            "ромашк" to CHRYSANTHEMUM, "гербер" to CHRYSANTHEMUM,
            "лаванд" to LAVENDER,
            "лимон" to CITRUS, "мандарин" to CITRUS, "апельсин" to CITRUS,
            "цитрус" to CITRUS, "каламондин" to CITRUS,
            "цвет" to PELARGONIUM,
            "базилик" to HERBS, "мят" to MINT,
            "зелень" to HERBS, "петрушк" to HERBS, "укроп" to HERBS,
            "кустик" to HERBS, "росток" to HERBS,
            "тюльпан" to TULIP, "лили" to LILY, "нарцисс" to TULIP,
            "гиацинт" to TULIP, "крокус" to TULIP, "подсолнух" to SUNFLOWER,
            "monst" to MONSTERA, "philodendron" to MONSTERA,
            "ficus" to FICUS, "rubber" to FICUS,
            "sansevier" to SANSEVIERIA, "trifasciata" to SANSEVIERIA,
            "snake plant" to SANSEVIERIA,
            "zamioculcas" to ZAMIOCULCAS, "zz plant" to ZAMIOCULCAS,
            "spathiphyll" to SPATHIPHYLLUM, "peace lily" to SPATHIPHYLLUM,
            "dieffenbach" to SPATHIPHYLLUM, "anthurium" to ANTHURIUM,
            "aglaonema" to SPATHIPHYLLUM,
            "orchid" to ORCHID, "phalaenopsis" to ORCHID,
            "alocasia" to ALOCASIA, "colocasia" to ALOCASIA,
            "elephant ear" to ALOCASIA,
            "aloe" to ALOE, "haworth" to HAWORTHIA, "gasteria" to HAWORTHIA,
            "agave" to ALOE,
            "opuntia" to OPUNTIA, "prickly pear" to OPUNTIA,
            "cact" to CACTUS, "kakt" to CACTUS, "mammillaria" to CACTUS,
            "echeveria" to ECHEVERIA, "sempervivum" to ECHEVERIA,
            "succulent" to ECHEVERIA,
            "crassula" to JADE, "jade" to JADE, "kalancho" to KALANCHOE,
            "dracaena" to DRACAENA, "yucca" to YUCCA, "nolina" to YUCCA,
            "cordyline" to DRACAENA,
            "chamaedorea" to PALM, "palm" to PALM, "bamboo" to PALM,
            "nephrolepis" to FERN, "fern" to FERN, "moss" to FERN,
            "hoya" to HOYA, "hedera" to IVY, "ivy" to IVY,
            "scindapsus" to IVY, "epipremnum" to IVY, "pothos" to IVY,
            "tradescantia" to IVY,
            "calathea" to CALATHEA, "maranta" to CALATHEA,
            "ctenanthe" to CALATHEA, "prayer plant" to CALATHEA,
            "pilea" to PILEA, "peperomia" to PILEA,
            "chlorophytum" to CHLOROPHYTUM, "spider plant" to CHLOROPHYTUM,
            "saintpaulia" to VIOLET, "violet" to VIOLET,
            "begonia" to BEGONIA,
            "pelargonium" to PELARGONIUM, "geranium" to PELARGONIUM,
            "rosmarinus" to ROSEMARY, "rosemary" to ROSEMARY,
            "sunflower" to SUNFLOWER, "helianthus" to SUNFLOWER,
            "chrysanthem" to CHRYSANTHEMUM, "daisy" to CHRYSANTHEMUM,
            "gerbera" to CHRYSANTHEMUM,
            "lavand" to LAVENDER, "lavender" to LAVENDER,
            "citrus" to CITRUS, "lemon" to CITRUS, "mandarin" to CITRUS,
            "calamondin" to CITRUS,
            "rose" to ROSE,
            "flower" to PELARGONIUM,
            "basil" to HERBS, "mint" to MINT, "mentha" to MINT,
            "parsley" to HERBS, "dill" to HERBS, "herb" to HERBS,
            "tulip" to TULIP, "lily" to LILY, "lilium" to LILY,
            "narcissus" to TULIP, "daffodil" to TULIP, "hyacinth" to TULIP,
            "crocus" to TULIP,
        )

        fun raw(name: String): Preset? = entries.firstOrNull { it.raw == name }
    }
}

/** Что взято со снимка: цвета листьев, цветов и горшка, густота и рост. */
@Serializable
data class Traits(
    val leaf: Channels,
    val variegation: Channels? = null,
    val flower: Channels? = null,
    val pot: Channels? = null,
    /** Во сколько раз гуще листва, чем у готовой модели: 0.75…1.35. */
    val density: Double = 1.0,
    /** Во сколько раз выше: 0.8…1.3. */
    val stretch: Double = 1.0,
)

/** Чертёж модели: вид и снятые со снимка черты. */
@Serializable
data class Blueprint(val preset: Preset, val traits: Traits? = null, val seed: String = preset.raw) {
    val source: String
        get() = if (traits == null) {
            Lang.format("Готовая модель: %@", preset.title.lowercase(Lang.locale))
        } else {
            Lang.format("Модель по снимку: %@", preset.title.lowercase(Lang.locale))
        }

    companion object {
        fun stock(species: String) = stock(Preset.of(species))
        fun stock(preset: Preset) = Blueprint(preset, null, preset.raw)
    }
}
