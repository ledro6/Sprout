#!/usr/bin/env python3
"""
Вытягивает дизайн из Figma REST API в машиночитаемый вид.

Использование:
    export FIGMA_TOKEN=figd_...
    python3 tool/figma_extract.py <figma-url-или-file-key> [--out design/]

Складывает в --out:
    raw.json        полный ответ /v1/files/<key> (справочно)
    screens.json    разобранное дерево: экраны, слои, геометрия, стили
    tokens.json     сводка дизайн-токенов (цвета, типографика, радиусы, тени)
    png/<name>.png  рендер каждого верхнеуровневого фрейма для сверки глазами

Токен нигде не сохраняется — читается только из переменной окружения.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.figma.com/v1"


def die(msg: str) -> "NoReturn":  # noqa: F821
    print(f"ошибка: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_file_key(s: str) -> str:
    """Принимает и голый key, и любую форму ссылки на файл Figma."""
    s = s.strip()
    m = re.search(r"figma\.com/(?:file|design|proto)/([A-Za-z0-9]+)", s)
    if m:
        return m.group(1)
    if re.fullmatch(r"[A-Za-z0-9]{10,}", s):
        return s
    die(f"не смог разобрать file key из {s!r}")


def parse_node_id(s: str) -> "str | None":
    """node-id из ссылки, если пользователь дал ссылку на конкретный фрейм."""
    q = urllib.parse.urlparse(s).query
    node = urllib.parse.parse_qs(q).get("node-id", [None])[0]
    # В ссылках Figma id приходит как 123-456, а API ждёт 123:456.
    return node.replace("-", ":") if node else None


def get(path: str, token: str, **params):
    url = f"{API}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"X-Figma-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:400]
        if e.code == 403:
            die("403 от Figma. Токен неверный, истёк, или у него нет скоупа "
                "file_content:read / нет доступа к этому файлу.")
        if e.code == 404:
            die("404 от Figma. Проверь ссылку на файл — такого key не видно "
                "под этим токеном.")
        die(f"HTTP {e.code} от Figma: {body}")


# ---------- преобразование значений Figma в удобный вид ----------

def to_hex(color: dict, opacity=None) -> str:
    if not color:
        return ""
    r, g, b = (round(color.get(k, 0) * 255) for k in ("r", "g", "b"))
    a = color.get("a", 1)
    if opacity is not None:
        a *= opacity
    if a >= 0.999:
        return f"#{r:02X}{g:02X}{b:02X}"
    return f"#{r:02X}{g:02X}{b:02X}{round(a * 255):02X}"


def paint(p: dict) -> dict:
    """Одна заливка/обводка: сплошной цвет или градиент."""
    if p.get("visible") is False:
        return {}
    t = p.get("type", "")
    if t == "SOLID":
        return {"type": "solid", "color": to_hex(p.get("color"), p.get("opacity"))}
    if t.startswith("GRADIENT"):
        return {
            "type": t.lower(),
            "stops": [
                {"pos": round(s.get("position", 0), 4),
                 "color": to_hex(s.get("color"), p.get("opacity"))}
                for s in p.get("gradientStops", [])
            ],
            # handles задают направление градиента в нормализованных координатах
            "handles": [[round(h.get("x", 0), 4), round(h.get("y", 0), 4)]
                        for h in p.get("gradientHandlePositions", [])],
        }
    if t == "IMAGE":
        return {"type": "image", "ref": p.get("imageRef"), "scaleMode": p.get("scaleMode")}
    return {"type": t.lower()}


def effects(node: dict) -> list:
    out = []
    for e in node.get("effects", []) or []:
        if e.get("visible") is False:
            continue
        out.append({
            "type": e.get("type", "").lower(),
            "color": to_hex(e.get("color")) if e.get("color") else None,
            "offset": [e.get("offset", {}).get("x", 0), e.get("offset", {}).get("y", 0)],
            "radius": e.get("radius", 0),
            "spread": e.get("spread", 0),
        })
    return out


def typography(node: dict) -> dict:
    s = node.get("style") or {}
    if not s:
        return {}
    return {
        "family": s.get("fontFamily"),
        "weight": s.get("fontWeight"),
        "size": s.get("fontSize"),
        "lineHeight": s.get("lineHeightPx"),
        "letterSpacing": round(s.get("letterSpacing", 0), 3),
        "align": s.get("textAlignHorizontal"),
        "case": s.get("textCase"),
        "decoration": s.get("textDecoration"),
    }


def autolayout(node: dict) -> dict:
    mode = node.get("layoutMode")
    if not mode or mode == "NONE":
        return {}
    return {
        "direction": "column" if mode == "VERTICAL" else "row",
        "gap": node.get("itemSpacing", 0),
        "padding": {
            "l": node.get("paddingLeft", 0), "r": node.get("paddingRight", 0),
            "t": node.get("paddingTop", 0), "b": node.get("paddingBottom", 0),
        },
        "mainAxis": node.get("primaryAxisAlignItems", "MIN"),
        "crossAxis": node.get("counterAxisAlignItems", "MIN"),
        "wrap": node.get("layoutWrap"),
    }


def radii(node: dict):
    if node.get("rectangleCornerRadii"):
        return node["rectangleCornerRadii"]
    r = node.get("cornerRadius")
    return r if r else 0


SKIP_INVISIBLE = True


def walk(node: dict, depth: int, origin=(0.0, 0.0)) -> dict:
    """Рекурсивно разбирает узел. Координаты приводит к локальным
    относительно родительского экрана — так их проще класть в Flutter."""
    if SKIP_INVISIBLE and node.get("visible") is False:
        return {}

    box = node.get("absoluteBoundingBox") or {}
    x = box.get("x", 0) - origin[0]
    y = box.get("y", 0) - origin[1]

    out = {
        "id": node.get("id"),
        "name": node.get("name"),
        "type": node.get("type"),
        "frame": {"x": round(x, 2), "y": round(y, 2),
                  "w": round(box.get("width", 0), 2),
                  "h": round(box.get("height", 0), 2)},
    }

    if node.get("opacity") is not None and node["opacity"] < 1:
        out["opacity"] = round(node["opacity"], 3)
    if node.get("rotation"):
        out["rotation"] = round(node["rotation"], 3)

    fills = [f for f in (paint(p) for p in node.get("fills", []) or []) if f]
    if fills:
        out["fills"] = fills
    strokes = [s for s in (paint(p) for p in node.get("strokes", []) or []) if s]
    if strokes:
        out["strokes"] = strokes
        out["strokeWeight"] = node.get("strokeWeight")

    r = radii(node)
    if r:
        out["radius"] = r
    fx = effects(node)
    if fx:
        out["effects"] = fx
    al = autolayout(node)
    if al:
        out["autolayout"] = al
    if node.get("clipsContent"):
        out["clipsContent"] = True

    if node.get("type") == "TEXT":
        out["text"] = node.get("characters", "")
        out["typography"] = typography(node)

    if node.get("type") in ("COMPONENT", "INSTANCE", "COMPONENT_SET"):
        out["component"] = node.get("componentId") or node.get("name")

    kids = [walk(c, depth + 1, origin) for c in node.get("children", []) or []]
    kids = [k for k in kids if k]
    if kids:
        out["children"] = kids
    return out


def collect_tokens(node: dict, acc: dict):
    """Считает, как часто встречается каждый цвет / стиль текста / радиус —
    частота помогает отличить настоящий токен от случайного значения."""
    for f in node.get("fills", []) or []:
        if f.get("type") == "solid" and f.get("color"):
            acc["colors"][f["color"]] = acc["colors"].get(f["color"], 0) + 1
    for s in node.get("strokes", []) or []:
        if s.get("type") == "solid" and s.get("color"):
            acc["colors"][s["color"]] = acc["colors"].get(s["color"], 0) + 1
    t = node.get("typography")
    if t and t.get("size"):
        key = f'{t.get("family")} {t.get("weight")} {t.get("size")}/{t.get("lineHeight")}'
        acc["type"][key] = acc["type"].get(key, 0) + 1
    r = node.get("radius")
    if isinstance(r, (int, float)) and r:
        acc["radii"][r] = acc["radii"].get(r, 0) + 1
    for e in node.get("effects", []) or []:
        key = f'{e["type"]} {e["color"]} off{e["offset"]} r{e["radius"]} s{e["spread"]}'
        acc["shadows"][key] = acc["shadows"].get(key, 0) + 1
    for c in node.get("children", []) or []:
        collect_tokens(c, acc)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("target", help="ссылка на файл Figma или file key")
    ap.add_argument("--out", default="design", help="куда сложить результат")
    ap.add_argument("--scale", type=float, default=2.0, help="масштаб PNG-рендеров")
    ap.add_argument("--no-png", action="store_true", help="не качать рендеры")
    args = ap.parse_args()

    token = os.environ.get("FIGMA_TOKEN", "").strip()
    if not token:
        die("не задан FIGMA_TOKEN. Сделай: export FIGMA_TOKEN=figd_...")

    key = parse_file_key(args.target)
    only_node = parse_node_id(args.target)

    os.makedirs(args.out, exist_ok=True)
    print(f"файл {key}" + (f", узел {only_node}" if only_node else ""))

    data = get(f"/files/{key}", token, geometry="paths")
    with open(os.path.join(args.out, "raw.json"), "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

    doc = data["document"]
    pages = [p for p in doc.get("children", []) if p.get("type") == "CANVAS"]
    print(f"название: {data.get('name')}")
    print(f"страниц: {len(pages)}")

    screens = []
    for page in pages:
        for frame in page.get("children", []) or []:
            if frame.get("type") not in ("FRAME", "COMPONENT", "COMPONENT_SET", "GROUP"):
                continue
            if only_node and frame.get("id") != only_node:
                continue
            box = frame.get("absoluteBoundingBox") or {}
            origin = (box.get("x", 0), box.get("y", 0))
            s = walk(frame, 0, origin)
            if not s:
                continue
            s["page"] = page.get("name")
            screens.append(s)

    if not screens:
        die("не нашёл ни одного фрейма верхнего уровня. "
            "Проверь, что экраны лежат как Frame на канвасе.")

    with open(os.path.join(args.out, "screens.json"), "w") as f:
        json.dump({"file": data.get("name"), "key": key, "screens": screens},
                  f, ensure_ascii=False, indent=1)

    acc = {"colors": {}, "type": {}, "radii": {}, "shadows": {}}
    for s in screens:
        collect_tokens(s, acc)
    tokens = {
        k: [{"value": v, "count": c}
            for v, c in sorted(d.items(), key=lambda kv: -kv[1])]
        for k, d in acc.items()
    }
    with open(os.path.join(args.out, "tokens.json"), "w") as f:
        json.dump(tokens, f, ensure_ascii=False, indent=1)

    print(f"\nэкранов: {len(screens)}")
    for s in screens:
        print(f"  {s['frame']['w']:>6.0f}x{s['frame']['h']:<6.0f} "
              f"[{s['page']}] {s['name']}")
    print(f"\nтокенов: {len(tokens['colors'])} цветов, "
          f"{len(tokens['type'])} стилей текста, "
          f"{len(tokens['radii'])} радиусов, {len(tokens['shadows'])} теней")

    if args.no_png:
        return

    png_dir = os.path.join(args.out, "png")
    os.makedirs(png_dir, exist_ok=True)
    ids = [s["id"] for s in screens]
    # API ограничивает длину запроса — тянем пачками.
    urls = {}
    for i in range(0, len(ids), 20):
        chunk = ids[i:i + 20]
        res = get(f"/images/{key}", token, ids=",".join(chunk),
                  format="png", scale=args.scale)
        urls.update(res.get("images") or {})

    def safe(n: str) -> str:
        return re.sub(r"[^\w\-.]+", "_", n).strip("_")[:60] or "frame"

    got = 0
    for s in screens:
        u = urls.get(s["id"])
        if not u:
            continue
        path = os.path.join(png_dir, f"{safe(s['name'])}.png")
        try:
            with urllib.request.urlopen(u, timeout=120) as r, open(path, "wb") as f:
                f.write(r.read())
            got += 1
        except Exception as e:  # рендер одного фрейма не должен валить всё
            print(f"  не скачал {s['name']}: {e}", file=sys.stderr)
    print(f"рендеров скачано: {got} → {png_dir}/")


if __name__ == "__main__":
    main()
