#!/usr/bin/env python3
"""
Синтезирует звуки приложения и кладёт их в каталог ресурсов.

    python3 tool/make_sounds.py [--preview путь.wav]

Звуки не записаны, а собраны из синусов и шума: так они короткие, чистые,
одной породы и пересобираются одной командой, если захочется другой тон.

Дружелюбные, а не стеклянные: калимба, колокольчик и маримба в войлоке,
на октаву ниже прежнего звона, с мягким входом и лёгким эхом комнаты.
Ноты — из до-мажорной пентатоники: в ней нет полутонов, и любые два звука,
сыгранные подряд, не спорят. Удаление и ошибка — не шипение и не гудок, а
две мягкие ноты вниз.

Выход — WAV, 44.1 кГц, моно, 16 бит, в наборы данных
Assets.xcassets/Sounds/chime-*.dataset; приложение читает их через
`NSDataAsset`, см. Design/Sound.swift. С `--preview` все звуки ещё и
складываются в один файл по очереди — послушать разом.
"""
import json
import os
import sys
import wave

try:
    import numpy as np
except ImportError:
    sys.exit('нужен numpy: pip install numpy')

RATE = 44_100
ROOT = os.path.join(os.path.dirname(__file__), '..', 'ios-native', 'Sprout',
                    'Assets.xcassets', 'Sounds')

# До-мажорная пентатоника, Гц.
C4, E4, G4, A4 = 261.63, 329.63, 392.00, 440.00
C5, D5, E5, G5, A5 = 523.25, 587.33, 659.25, 783.99, 880.00
C6, D6, E6 = 1046.50, 1174.66, 1318.51


def clock(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def attack(t, seconds=0.008):
    """Мягкий вход: короче — щелчок, длиннее — звук опаздывает к нажатию."""
    return 1 - np.exp(-t / seconds)


def tone(freq, seconds, fade, partials, rise=0.008):
    """Нота из призвуков: (кратность, громкость, доля затухания)."""
    t = clock(seconds)
    out = np.zeros_like(t)
    for ratio, level, life in partials:
        out += level * np.sin(2 * np.pi * freq * ratio * t) \
            * np.exp(-t / (fade * life))
    return out * attack(t, rise)


def kalimba(freq, seconds=0.9, fade=0.32):
    """Язычок калимбы: круглый тон и короткое «динь» сверху."""
    return tone(freq, seconds, fade,
                ((1, 1, 1), (2, 0.1, 0.5), (5.4, 0.06, 0.08)), rise=0.005)


def bell(freq, seconds=1.0, fade=0.38):
    """Колокольчик музыкальной шкатулки: октава и квинта над ней тише."""
    return tone(freq, seconds, fade,
                ((1, 1, 1), (2, 0.22, 0.45), (3, 0.06, 0.25)))


def felt(freq, seconds=0.7, fade=0.2):
    """Маримба в войлоке: стука палочки почти не слышно."""
    return tone(freq, seconds, fade,
                ((1, 1, 1), (4, 0.08, 0.12), (2, 0.05, 0.3)), rise=0.01)


def drop(f0, f1, glide, seconds, fade):
    """Капля: тон взлетает и гаснет — «блоп»."""
    t = clock(seconds)
    rise = np.minimum(t / glide, 1)
    freq = f0 * (f1 / f0) ** rise
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) * attack(t, 0.004) * np.exp(-t / fade)


def glide(f0, f1, seconds, fade):
    """Скольжение тона — взмах вверх или вниз, тихо, под нотами."""
    t = clock(seconds)
    freq = f0 * (f1 / f0) ** np.minimum(t / seconds, 1)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) * attack(t, 0.01) * np.exp(-t / fade)


def lowpass(sound, cutoff):
    """Два однополюсных фильтра подряд: верх мягче, без шипения."""
    gain = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    out = np.zeros_like(sound)
    a = b = 0.0
    for i, x in enumerate(sound):
        a += gain * (x - a)
        b += gain * (a - b)
        out[i] = b
    return out


def noise_band(seconds, top, bottom, rng):
    """Шум, у которого срез уезжает сверху вниз, — тихий шорох."""
    n = int(seconds * RATE)
    noise = rng.uniform(-1, 1, n)
    cut = top * (bottom / top) ** (np.arange(n) / n)
    gain = 1 - np.exp(-2 * np.pi * cut / RATE)
    out = np.zeros(n)
    a = b = 0.0
    for i in range(n):
        a += gain[i] * (noise[i] - a)
        b += gain[i] * (a - b)
        out[i] = b
    t = clock(seconds)
    return out * attack(t, 0.05) * np.exp(-t / (seconds * 0.35))


def comb(sound, delay, feedback):
    """Гребёнка блоками по длине задержки: без цикла по отсчётам."""
    step = int(delay * RATE)
    out = sound.copy()
    for start in range(step, len(out), step):
        end = min(start + step, len(out))
        out[start:end] += feedback * out[start - step:end - step]
    return out


def room(sound, wet=0.16, size=0.55):
    """Эхо маленькой комнаты по Шрёдеру: звук не висит в пустоте. Хвост
    добавляется к длине, иначе его обрезало бы."""
    padded = np.concatenate([sound, np.zeros(int(0.35 * RATE))])
    tail = np.zeros_like(padded)
    for delay in (0.0297, 0.0371, 0.0411, 0.0437):
        tail += comb(padded, delay, 0.62 * size + 0.2)
    return padded + wet * lowpass(tail / 4, 3800)


def mix(seconds, *parts):
    """Части — (с какой секунды, звук)."""
    out = np.zeros(int(seconds * RATE))
    for start, sound in parts:
        at = int(start * RATE)
        end = min(len(out), at + len(sound))
        out[at:end] += sound[:end - at]
    return out


def pour():
    """Полив: два «блопа» капель и тёплое «динь-дон» калимбы."""
    return room(mix(0.95,
                    (0.00, 0.85 * drop(330, 720, 0.05, 0.25, 0.05)),
                    (0.10, 0.50 * drop(420, 880, 0.045, 0.2, 0.04)),
                    (0.18, 0.55 * kalimba(G5, 0.75, 0.26)),
                    (0.30, 0.45 * kalimba(C6, 0.65, 0.24))))


def plant():
    """Посадка: весёлое арпеджио калимбы вверх и мягкий бас."""
    return room(mix(1.35,
                    (0.000, 0.35 * felt(C4, 1.1, 0.4)),
                    (0.000, 0.70 * kalimba(C5)),
                    (0.085, 0.70 * kalimba(E5)),
                    (0.170, 0.75 * kalimba(G5)),
                    (0.255, 0.85 * kalimba(C6, 1.0, 0.4))), wet=0.2)


def toss(rng):
    """Удаление: две мягкие ноты вниз — «пока» — и едва слышный шорох."""
    return room(mix(0.75,
                    (0.00, 0.12 * lowpass(noise_band(0.4, 1400, 300, rng),
                                          1800)),
                    (0.00, 0.80 * felt(G5, 0.5, 0.16)),
                    (0.11, 0.85 * felt(C5, 0.6, 0.22)),
                    (0.00, 0.12 * glide(700, 350, 0.25, 0.1))))


def undo():
    """Возврат: взмах и две ноты вверх — всё вернулось."""
    return room(mix(0.8,
                    (0.00, 0.18 * glide(330, 660, 0.12, 0.08)),
                    (0.05, 0.75 * kalimba(C5, 0.6, 0.22)),
                    (0.14, 0.85 * kalimba(G5, 0.65, 0.26))))


def save():
    """Сохранено: колокольчик в два тона, тихо."""
    return room(mix(0.95,
                    (0.00, 0.70 * bell(E5, 0.8, 0.3)),
                    (0.08, 0.65 * bell(A5, 0.85, 0.34))))


def wrong():
    """Не вышло: «хм-хм» — две круглые низкие ноты вниз, без гудка."""
    return room(mix(0.6,
                    (0.00, 0.85 * felt(A4, 0.3, 0.1)),
                    (0.14, 0.80 * felt(E4, 0.4, 0.13))), wet=0.1)


def stream(rng):
    """Струя из лейки: мягкое журчание — полоса шума, которая дрожит, — и
    редкие негромкие капли. Длится столько же, сколько льёт лейка в сцене."""
    seconds = 2.2
    n = int(seconds * RATE)
    noise = rng.uniform(-1, 1, n)
    high = 1 - np.exp(-2 * np.pi * 1600 / RATE)
    low = 1 - np.exp(-2 * np.pi * 260 / RATE)
    band = np.zeros(n)
    a = b = 0.0
    for i in range(n):
        a += high * (noise[i] - a)
        b += low * (noise[i] - b)
        band[i] = a - b
    t = clock(seconds)
    # Журчание не ровное: громкость дрожит с частотой в несколько герц.
    wobble = 0.75 + 0.25 * np.sin(2 * np.pi * 7 * t) \
        * np.sin(2 * np.pi * 1.9 * t)
    shape = np.minimum(t / 0.2, 1) * np.minimum((seconds - t) / 0.5, 1)
    water = lowpass(band * wobble * np.clip(shape, 0, 1), 2400)
    parts = [(0.0, water)]
    for _ in range(16):
        start = rng.uniform(0.15, seconds - 0.3)
        note = rng.uniform(380, 620)
        parts.append((start, rng.uniform(0.08, 0.16)
                      * drop(note, note * 1.9, 0.035, 0.14, 0.03)))
    return mix(seconds, *parts)


def frolic(rng):
    """Кутерьма от тряски: по такту узора — прыгающие ноты калимбы, в
    последнем такте — аккорд, которым узор садится на место. Такт тот же,
    что у `Frolic.beat`."""
    beat = 0.7
    scale = [C5, D5, E5, G5, A5, C6]
    parts = []
    for n in range(5):
        for half in (0.0, 0.5):
            note = scale[rng.integers(len(scale))]
            level = 0.7 - 0.07 * n
            parts.append((n * beat + half * beat,
                          level * kalimba(note, 0.5, 0.14)))
    settle = 5 * beat
    for k, note in enumerate((C5, E5, G5)):
        parts.append((settle + 0.04 * k, 0.55 * felt(note, 1.0, 0.35)))
    parts.append((settle + 0.15, 0.4 * bell(C6, 0.9, 0.3)))
    return room(mix(4.8, *parts))


LOUDNESS = {
    'pour': 0.38, 'plant': 0.4, 'toss': 0.34, 'undo': 0.36,
    'save': 0.32, 'wrong': 0.3, 'frolic': 0.34, 'stream': 0.24,
}


def finish(sound, peak):
    """Громкость по пику и тихий хвост: обрыв на полуслове щёлкает."""
    sound = sound / np.max(np.abs(sound)) * peak
    tail = min(len(sound), int(0.02 * RATE))
    sound[-tail:] *= np.linspace(1, 0, tail)
    return sound


def write(path, sound):
    pcm = np.clip(np.round(sound * 32767), -32768, 32767).astype('<i2')
    with wave.open(path, 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def dataset(name, sound):
    folder = os.path.join(ROOT, f'chime-{name}.dataset')
    os.makedirs(folder, exist_ok=True)
    write(os.path.join(folder, f'chime-{name}.wav'), sound)
    contents = {
        'data': [{
            'filename': f'chime-{name}.wav',
            'idiom': 'universal',
            'universal-type-identifier': 'com.microsoft.waveform-audio',
        }],
        'info': {'author': 'xcode', 'version': 1},
    }
    with open(os.path.join(folder, 'Contents.json'), 'w') as out:
        json.dump(contents, out, indent=2)
        out.write('\n')


def main():
    preview = None
    if len(sys.argv) == 3 and sys.argv[1] == '--preview':
        preview = sys.argv[2]
    elif len(sys.argv) != 1:
        sys.exit(__doc__)

    # Шум и случайные ноты — с одним зерном: пересборка даёт те же файлы.
    rng = np.random.default_rng(7)
    sounds = {
        'pour': pour(), 'plant': plant(), 'toss': toss(rng),
        'undo': undo(), 'save': save(), 'wrong': wrong(),
        'frolic': frolic(rng), 'stream': stream(rng),
    }

    os.makedirs(ROOT, exist_ok=True)
    with open(os.path.join(ROOT, 'Contents.json'), 'w') as out:
        json.dump({'info': {'author': 'xcode', 'version': 1}}, out, indent=2)
        out.write('\n')

    gap = np.zeros(int(0.7 * RATE))
    reel = []
    for name, sound in sounds.items():
        done = finish(sound, LOUDNESS[name])
        dataset(name, done)
        reel += [done, gap]
        print(f'  chime-{name}: {len(done) / RATE:.2f} с')
    if preview:
        write(preview, np.concatenate(reel))
        print(f'  все подряд: {preview}')


if __name__ == '__main__':
    main()
