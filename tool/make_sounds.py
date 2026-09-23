#!/usr/bin/env python3
"""
Синтезирует звуки приложения и кладёт их в каталог ресурсов.

    python3 tool/make_sounds.py [--preview путь.wav]

Звуки не записаны, а собраны из синусов и шума: так они короткие, чистые,
одной породы и пересобираются одной командой, если захочется другой тон.
Каждый — набор нот с затуханием; ноты берутся из до мажора, чтобы любые два
звука, сыгранные подряд, не спорили друг с другом.

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

# Ноты до мажора, Гц.
C5, G5 = 523.25, 783.99
C6, D6, E6, G6, A6 = 1046.50, 1174.66, 1318.51, 1567.98, 1760.00
B6, C7 = 1975.53, 2093.00


def clock(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def attack(t, seconds=0.003):
    """Мягкий вход: без него начало ноты щёлкает."""
    return 1 - np.exp(-t / seconds)


def drop(f0, f1, glide, seconds, fade):
    """Капля: тон быстро взлетает и гаснет — «бульк»."""
    t = clock(seconds)
    rise = np.minimum(t / glide, 1)
    freq = f0 * (f1 / f0) ** rise
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase) * attack(t, 0.0015) * np.exp(-t / fade)


def chime(freq, seconds, fade, partials=((1, 1, 1), (2, 0.12, 0.4))):
    """Стеклянная нота: основной тон и тихая октава, которая гаснет раньше."""
    t = clock(seconds)
    out = np.zeros_like(t)
    for ratio, level, life in partials:
        out += level * np.sin(2 * np.pi * freq * ratio * t) \
            * np.exp(-t / (fade * life))
    return out * attack(t)


def marimba(freq, seconds, fade):
    """Деревянная нота: верхний призвук гаснет почти сразу — стук палочки."""
    return chime(freq, seconds, fade, ((1, 1, 1), (3.93, 0.35, 0.12),
                                       (9.3, 0.08, 0.05)))


def bounce(freq, seconds, fade):
    """Нота с лёгким провалом высоты — как мячик."""
    t = clock(seconds)
    bend = freq * (1 + 0.06 * np.exp(-t / 0.03))
    phase = 2 * np.pi * np.cumsum(bend) / RATE
    tone = np.sin(phase) + 0.1 * np.sin(2 * phase)
    return tone * attack(t) * np.exp(-t / fade)


def whoosh(seconds, top, bottom, rng):
    """Шум, у которого срез уезжает сверху вниз, — смахнули."""
    n = int(seconds * RATE)
    noise = rng.uniform(-1, 1, n)
    cut = top * (bottom / top) ** (np.arange(n) / n)
    gain = 1 - np.exp(-2 * np.pi * cut / RATE)
    # Два фильтра подряд: срез мягче, шум не шипит.
    soft = np.zeros(n)
    a = b = 0.0
    for i in range(n):
        a += gain[i] * (noise[i] - a)
        b += gain[i] * (a - b)
        soft[i] = b
    t = clock(seconds)
    shape = attack(t, 0.04) * np.exp(-t / (seconds * 0.35))
    return soft * shape


def mix(seconds, *parts):
    """Части — (с какой секунды, звук)."""
    out = np.zeros(int(seconds * RATE))
    for start, sound in parts:
        at = int(start * RATE)
        end = min(len(out), at + len(sound))
        out[at:end] += sound[:end - at]
    return out


def pour():
    """Полив: три капли подряд и тихий блик воды."""
    return mix(1.0,
               (0.00, 1.00 * drop(520, 1250, 0.045, 0.25, 0.040)),
               (0.09, 0.55 * drop(690, 1600, 0.040, 0.20, 0.034)),
               (0.17, 0.40 * drop(600, 1450, 0.040, 0.20, 0.030)),
               (0.26, 0.20 * chime(E6, 0.7, 0.22)),
               (0.34, 0.14 * chime(B6, 0.6, 0.18)))


def plant():
    """Посадка: восходящее арпеджио на маримбе с опорой внизу."""
    return mix(1.3,
               (0.000, 0.30 * marimba(C5, 1.2, 0.45)),
               (0.000, 0.75 * marimba(G5, 1.0, 0.30)),
               (0.075, 0.75 * marimba(C6, 1.0, 0.30)),
               (0.150, 0.80 * marimba(E6, 1.0, 0.32)),
               (0.225, 0.90 * marimba(G6, 1.0, 0.40)))


def toss(rng):
    """Удаление: вниз уходящий шорох и тон, который съезжает следом."""
    t = clock(0.35)
    freq = 660 * (0.5 ** np.minimum(t / 0.25, 1))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    tone = np.sin(phase) * attack(t) * np.exp(-t / 0.10)
    return mix(0.6,
               (0.00, 1.00 * whoosh(0.55, 3200, 260, rng)),
               (0.02, 0.35 * tone))


def undo():
    """Возврат: взлёт и две ноты вверх — всё вернулось."""
    t = clock(0.12)
    freq = 440 * (2 ** np.minimum(t / 0.07, 1))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    swoop = np.sin(phase) * attack(t) * np.exp(-t / 0.05)
    return mix(0.75,
               (0.00, 0.35 * swoop),
               (0.06, 0.75 * chime(C6, 0.6, 0.20)),
               (0.13, 0.85 * chime(G6, 0.6, 0.24)))


def save():
    """Сохранено: мягкая двойная нота."""
    return mix(0.9,
               (0.00, 0.70 * chime(E6, 0.8, 0.30)),
               (0.07, 0.60 * chime(A6, 0.8, 0.34)))


def wrong():
    """Не вышло: два глухих «тук» вниз."""
    return mix(0.45,
               (0.00, bounce(440, 0.2, 0.06)),
               (0.12, 0.85 * bounce(330, 0.25, 0.07)))


def stream(rng):
    """Струя из лейки: журчание — полоса шума, которая дрожит, — и капли,
    бьющие по земле. Длится столько же, сколько льёт лейка в сцене."""
    seconds = 2.2
    n = int(seconds * RATE)
    noise = rng.uniform(-1, 1, n)
    high = 1 - np.exp(-2 * np.pi * 2600 / RATE)
    low = 1 - np.exp(-2 * np.pi * 420 / RATE)
    band = np.zeros(n)
    a = b = 0.0
    for i in range(n):
        a += high * (noise[i] - a)
        b += low * (noise[i] - b)
        band[i] = a - b
    t = clock(seconds)
    # Журчание не ровное: громкость дрожит с частотой в несколько герц.
    wobble = 0.7 + 0.3 * np.sin(2 * np.pi * 9 * t) * np.sin(2 * np.pi * 2.3 * t)
    shape = np.minimum(t / 0.15, 1) * np.minimum((seconds - t) / 0.45, 1)
    water = band * wobble * np.clip(shape, 0, 1)
    parts = [(0.0, water)]
    for _ in range(26):
        start = rng.uniform(0.12, seconds - 0.3)
        low_note = rng.uniform(700, 1100)
        parts.append((start, rng.uniform(0.08, 0.2)
                      * drop(low_note, low_note * 2.1, 0.03, 0.12, 0.025)))
    return mix(seconds, *parts)


def frolic(rng):
    """Кутерьма от тряски: по такту узора — прыгающие ноты, в последнем
    такте — аккорд, которым узор садится на место. Такт тот же, что у
    `Frolic.beat`."""
    beat = 0.7
    scale = [C6, D6, E6, G6, A6, C7]
    parts = []
    for n in range(5):
        for half in (0.0, 0.5):
            note = scale[rng.integers(len(scale))]
            level = 0.75 - 0.08 * n
            parts.append((n * beat + half * beat,
                          level * bounce(note, 0.5, 0.12)))
    settle = 5 * beat
    for k, note in enumerate((C6, E6, G6)):
        parts.append((settle + 0.035 * k, 0.55 * marimba(note, 1.0, 0.35)))
    parts.append((settle + 0.14, 0.35 * chime(C7, 0.9, 0.3)))
    return mix(4.8, *parts)


LOUDNESS = {
    'pour': 0.55, 'plant': 0.45, 'toss': 0.40, 'undo': 0.42,
    'save': 0.38, 'wrong': 0.36, 'frolic': 0.38, 'stream': 0.3,
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
