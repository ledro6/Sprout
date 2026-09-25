#!/usr/bin/env python3
"""
Готовые модели видов для Android: из тех же файлов, что лежат в приложении
iOS (ios-native/…/Stock/stock-<вид>.kit), — в GLB для ARCore и Filament.

    python3 android/tool/kit_to_glb.py build   # записать модели и картинки
    python3 android/tool/kit_to_glb.py check   # всё ли на месте и свежее

Файлы iOS только читаются. Что получается на каждый вид:

    assets/models/<вид>.glb    — сетки, материалы, текстуры; деталь — узел
                                 «piece-<номер>» с той же позой, что на iPhone;
    assets/models/<вид>.json   — то, чего нет в glTF: провисание и качание
                                 деталей, какие материалы вянут и мокнут, роль
                                 материала (горшок, земля, лист, цветок) и его
                                 средний цвет — для перекраски «по фото»;
    assets/previews/<вид>.png  — картинка модели для экрана «Модель для AR»,
                                 нарисована здесь же из готового GLB: она же
                                 проверка, что модель собралась правильно.

Формат .kit — см. Kit.swift: сжат raw deflate (`NSData … .zlib`), числа —
little-endian. Картинки — RGBA без премультипликации, строка 0 сверху; у
iOS ось v смотрит вверх, у glTF — вниз, поэтому v = 1 - v.
"""
import hashlib
import io
import json
import math
import struct
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image

ANDROID = Path(__file__).resolve().parent.parent
ROOT = ANDROID.parent
STOCK = ROOT / "ios-native" / "Sprout" / "Assets.xcassets" / "Stock"
ASSETS = ANDROID / "app" / "src" / "main" / "assets"
MODELS = ASSETS / "models"
PREVIEWS = ASSETS / "previews"

MAGIC = 0x5350_4B54
VERSION = 2
WILTS, WETS, CUTOUT = 2, 4, 1


# ---------------------------------------------------------------- чтение

class Tape:
    def __init__(self, data):
        self.data = data
        self.at = 0

    def word(self):
        value = struct.unpack_from("<I", self.data, self.at)[0]
        self.at += 4
        return value

    def signed(self):
        value = struct.unpack_from("<i", self.data, self.at)[0]
        self.at += 4
        return value

    def floats(self, count):
        values = np.frombuffer(self.data, "<f4", count, self.at).astype(np.float32)
        self.at += 4 * count
        return values

    def words(self, count):
        values = np.frombuffer(self.data, "<u4", count, self.at).astype(np.uint32)
        self.at += 4 * count
        return values

    def bytes(self, count):
        values = self.data[self.at:self.at + count]
        self.at += count
        return values


def read_kit(path):
    data = zlib.decompress(path.read_bytes(), -15)
    tape = Tape(data)
    if tape.word() != MAGIC or tape.word() != VERSION:
        raise SystemExit(f"{path.name}: не .kit версии {VERSION}")
    kit = {"height": float(tape.floats(1)[0]), "spread": float(tape.floats(1)[0])}
    meshes = []
    for _ in range(tape.word()):
        points, count = tape.word(), tape.word()
        mesh = {
            "positions": tape.floats(points * 3).reshape(-1, 3),
            "normals": tape.floats(points * 3).reshape(-1, 3),
            "uvs": tape.floats(points * 2).reshape(-1, 2),
            "indices": tape.words(count),
        }
        if count and int(mesh["indices"].max()) >= points:
            raise SystemExit(f"{path.name}: индекс за пределами сетки")
        meshes.append(mesh)
    pictures = []
    for _ in range(tape.word()):
        width, height = tape.word(), tape.word()
        pixels = np.frombuffer(tape.bytes(width * height * 4), np.uint8).reshape(height, width, 4)
        pictures.append(pixels)
    looks = []
    for _ in range(tape.word()):
        color, normal = tape.signed(), tape.signed()
        values = tape.floats(6)
        flags = tape.word()
        looks.append({
            "color": None if color < 0 else color,
            "normal": None if normal < 0 else normal,
            "tint": [float(v) for v in values[:3]],
            "rough": float(values[3]),
            "gloss": float(values[4]),
            "opacity": float(values[5]),
            "cutout": bool(flags & CUTOUT),
            "wilts": bool(flags & WILTS),
            "wets": bool(flags & WETS),
        })
    pieces = []
    for _ in range(tape.word()):
        mesh, look = tape.word(), tape.word()
        v = [float(x) for x in tape.floats(11)]
        pieces.append({
            "mesh": mesh, "look": look,
            "base": v[0:3], "yaw": v[3], "rise": v[4], "roll": v[5], "size": v[6],
            "sag": v[7], "sway": v[8], "delay": v[9], "phase": v[10],
        })
    if tape.at != len(data):
        raise SystemExit(f"{path.name}: лишние байты в конце")
    kit.update(meshes=meshes, pictures=pictures, looks=looks, pieces=pieces)
    return kit


# ---------------------------------------------------------------- математика

def quat(axis, angle):
    s = math.sin(angle / 2)
    return np.array([axis[0] * s, axis[1] * s, axis[2] * s, math.cos(angle / 2)])


def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return np.array([
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    ])


def orientation(piece, lean=0.0):
    """Как Bed.orientation на iPhone: поворот вокруг вертикали · подъём · крен."""
    return qmul(qmul(quat((0, 1, 0), piece["yaw"]), quat((0, 0, 1), piece["rise"] - lean)),
                quat((1, 0, 0), piece["roll"]))


def matrix(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def linear(srgb):
    c = np.asarray(srgb, dtype=np.float64) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


# ---------------------------------------------------------------- роли материалов

def hue(rgb):
    r, g, b = [c / 255 for c in rgb]
    top, low = max(r, g, b), min(r, g, b)
    if top - low < 0.08:
        return None
    if top == r:
        h = ((g - b) / (top - low)) % 6
    elif top == g:
        h = (b - r) / (top - low) + 2
    else:
        h = (r - g) / (top - low) + 4
    return h * 60


def mean_colour(kit, look):
    """Средний цвет материала, как его видно: текстура (по непрозрачным точкам) × оттенок."""
    tint = np.array(look["tint"])
    if look["color"] is None:
        return [round(float(c), 1) for c in tint]
    pixels = kit["pictures"][look["color"]].astype(np.float64)
    alpha = pixels[..., 3:4] / 255
    weight = max(float(alpha.sum()), 1e-6)
    mean = (pixels[..., :3] * alpha).reshape(-1, 3).sum(axis=0) / weight
    return [round(float(c), 1) for c in mean * tint / 255]


def roles(kit):
    """Горшок — у первой детали; земля мокнет; лист вянет; цветок — вырезной и не зелёный."""
    out = []
    pot = kit["pieces"][0]["look"] if kit["pieces"] else -1
    for index, look in enumerate(kit["looks"]):
        colour = mean_colour(kit, look)
        h = hue(colour)
        saturation = (max(colour) - min(colour)) / max(max(colour), 1)
        if look["wets"]:
            role = "soil"
        elif index == pot:
            role = "pot"
        elif look["wilts"]:
            role = "leaf"
        elif look["cutout"] and look["color"] is not None and not (h is not None and 60 <= h <= 175 and saturation > 0.15):
            # Лепестки — вырезные, не вянут и не зелёные; зелёные вырезные — чашелистики.
            role = "flower"
        else:
            role = "other"
        out.append((role, colour))
    return out


# ---------------------------------------------------------------- GLB

def encode_image(pixels, normal=False):
    """Цвет с прозрачностью — PNG; без неё — JPEG (меньше); рельеф — PNG без альфы."""
    image = Image.fromarray(pixels, "RGBA")
    buffer = io.BytesIO()
    if normal:
        image.convert("RGB").save(buffer, "PNG", optimize=True)
        return buffer.getvalue(), "image/png"
    if pixels[..., 3].min() < 255:
        image.save(buffer, "PNG", optimize=True)
        return buffer.getvalue(), "image/png"
    image.convert("RGB").save(buffer, "JPEG", quality=90, optimize=True)
    return buffer.getvalue(), "image/jpeg"


class Builder:
    def __init__(self):
        self.blob = bytearray()
        self.views = []
        self.accessors = []

    def view(self, data, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        view = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.blob.extend(data)
        self.views.append(view)
        return len(self.views) - 1

    def accessor(self, array, kind, component, target, bounds=False):
        data = np.ascontiguousarray(array).tobytes()
        accessor = {
            "bufferView": self.view(data, target),
            "componentType": component,
            "count": int(array.shape[0]),
            "type": kind,
        }
        if bounds:
            accessor["min"] = [float(v) for v in array.min(axis=0)]
            accessor["max"] = [float(v) for v in array.max(axis=0)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1


def to_glb(kit, name):
    builder = Builder()
    images, textures = [], []
    picture_texture = {}

    def texture(index, normal=False):
        key = (index, normal)
        if key not in picture_texture:
            data, mime = encode_image(kit["pictures"][index], normal)
            images.append({"bufferView": builder.view(data), "mimeType": mime})
            textures.append({"sampler": 0, "source": len(images) - 1})
            picture_texture[key] = len(textures) - 1
        return picture_texture[key]

    materials = []
    clearcoat = False
    for index, look in enumerate(kit["looks"]):
        colour = [float(c) for c in linear(look["tint"])]
        pbr = {
            "baseColorFactor": colour + [look["opacity"]],
            "metallicFactor": 0.0,
            "roughnessFactor": look["rough"],
        }
        if look["color"] is not None:
            pbr["baseColorTexture"] = {"index": texture(look["color"])}
        material = {"name": f"look-{index}", "pbrMetallicRoughness": pbr}
        if look["normal"] is not None:
            material["normalTexture"] = {"index": texture(look["normal"], normal=True)}
        if look["cutout"] and look["color"] is not None:
            material["alphaMode"] = "MASK"
            material["alphaCutoff"] = 0.5
        elif look["opacity"] < 1:
            material["alphaMode"] = "BLEND"
        if look["gloss"] > 0:
            clearcoat = True
            material["extensions"] = {"KHR_materials_clearcoat": {
                "clearcoatFactor": look["gloss"], "clearcoatRoughnessFactor": 0.12}}
        materials.append(material)

    meshes, mesh_of = [], {}
    for piece in kit["pieces"]:
        key = (piece["mesh"], piece["look"])
        if key in mesh_of:
            continue
        source = kit["meshes"][piece["mesh"]]
        if not len(source["indices"]):
            mesh_of[key] = None
            continue
        uvs = source["uvs"].copy()
        uvs[:, 1] = 1 - uvs[:, 1]
        normals = source["normals"].astype(np.float32)
        length = np.linalg.norm(normals, axis=1, keepdims=True)
        normals = np.where(length > 1e-8, normals / np.maximum(length, 1e-8), np.array([0, 1, 0], np.float32))
        attributes = {
            "POSITION": builder.accessor(source["positions"].astype(np.float32), "VEC3", 5126, 34962, bounds=True),
            "NORMAL": builder.accessor(normals.astype(np.float32), "VEC3", 5126, 34962),
            "TEXCOORD_0": builder.accessor(uvs.astype(np.float32), "VEC2", 5126, 34962),
        }
        indices = source["indices"]
        if len(source["positions"]) < 65536:
            index_accessor = builder.accessor(indices.astype(np.uint16), "SCALAR", 5123, 34963)
        else:
            index_accessor = builder.accessor(indices.astype(np.uint32), "SCALAR", 5125, 34963)
        meshes.append({
            "name": f"mesh-{piece['mesh']}-{piece['look']}",
            "primitives": [{"attributes": attributes, "indices": index_accessor, "material": piece["look"], "mode": 4}],
        })
        mesh_of[key] = len(meshes) - 1

    nodes = [{"name": "plant", "children": []}]
    for index, piece in enumerate(kit["pieces"]):
        node = {
            "name": f"piece-{index}",
            "translation": piece["base"],
            "rotation": [float(v) for v in orientation(piece)],
            "scale": [piece["size"]] * 3,
        }
        mesh = mesh_of[(piece["mesh"], piece["look"])]
        if mesh is not None:
            node["mesh"] = mesh
        nodes.append(node)
        nodes[0]["children"].append(len(nodes) - 1)

    gltf = {
        "asset": {"version": "2.0", "generator": "Sprout kit_to_glb.py"},
        "scene": 0,
        "scenes": [{"name": name, "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "textures": textures,
        "images": images,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.blob)}],
    }
    if clearcoat:
        gltf["extensionsUsed"] = ["KHR_materials_clearcoat"]
    if not textures:
        for key in ("samplers", "textures", "images"):
            del gltf[key]
    text = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    text += b" " * ((4 - len(text) % 4) % 4)
    blob = bytes(builder.blob) + b"\0" * ((4 - len(builder.blob) % 4) % 4)
    total = 12 + 8 + len(text) + 8 + len(blob)
    return (struct.pack("<III", 0x46546C67, 2, total)
            + struct.pack("<II", len(text), 0x4E4F534A) + text
            + struct.pack("<II", len(blob), 0x004E4942) + blob)


def sidecar(kit, source):
    looks = []
    for (role, colour), look in zip(roles(kit), kit["looks"]):
        looks.append({
            "role": role, "mean": colour, "tint": look["tint"], "opacity": look["opacity"],
            "wilts": look["wilts"], "wets": look["wets"],
        })
    pieces = [{
        "look": p["look"], "base": [round(v, 5) for v in p["base"]],
        "yaw": round(p["yaw"], 5), "rise": round(p["rise"], 5), "roll": round(p["roll"], 5),
        "size": round(p["size"], 5), "sag": round(p["sag"], 4), "sway": round(p["sway"], 4),
        "delay": round(p["delay"], 4), "phase": round(p["phase"], 4),
    } for p in kit["pieces"]]
    return {
        "source": source, "height": round(kit["height"], 4), "spread": round(kit["spread"], 4),
        "looks": looks, "pieces": pieces,
    }


# ---------------------------------------------------------------- проверка чтением GLB

def read_glb(data):
    magic, version, total = struct.unpack_from("<III", data, 0)
    if magic != 0x46546C67 or version != 2 or total != len(data):
        raise SystemExit("GLB: неверный заголовок")
    length, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise SystemExit("GLB: нет JSON")
    gltf = json.loads(data[20:20 + length])
    at = 20 + length
    blob_length, kind = struct.unpack_from("<II", data, at)
    if kind != 0x004E4942:
        raise SystemExit("GLB: нет BIN")
    blob = data[at + 8:at + 8 + blob_length]
    if gltf["buffers"][0]["byteLength"] > len(blob):
        raise SystemExit("GLB: буфер короче заявленного")
    return gltf, blob


def accessor_array(gltf, blob, index):
    accessor = gltf["accessors"][index]
    view = gltf["bufferViews"][accessor["bufferView"]]
    dtype = {5126: "<f4", 5123: "<u2", 5125: "<u4"}[accessor["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[accessor["type"]]
    array = np.frombuffer(blob, dtype, accessor["count"] * width, view["byteOffset"])
    return array.reshape(accessor["count"], width) if width > 1 else array


def decode_textures(gltf, blob):
    out = []
    for image in gltf.get("images", []):
        view = gltf["bufferViews"][image["bufferView"]]
        data = blob[view["byteOffset"]:view["byteOffset"] + view["byteLength"]]
        out.append(np.asarray(Image.open(io.BytesIO(data)).convert("RGBA")))
    return out


def render(data, width=520, height=400):
    """Картинка готового GLB: растеризатор с глубиной, текстурами, вырезом и мягким светом."""
    gltf, blob = read_glb(data)
    pictures = decode_textures(gltf, blob)
    textures = gltf.get("textures", [])
    yaw, pitch = math.radians(-28), math.radians(-17)
    turn = matrix(qmul(quat((1, 0, 0), pitch), quat((0, 1, 0), yaw)))
    light = np.array([-0.45, 0.8, 0.55])
    light /= np.linalg.norm(light)
    items = []
    lo, hi = np.full(3, np.inf), np.full(3, -np.inf)
    for index in gltf["nodes"][0]["children"]:
        node = gltf["nodes"][index]
        if "mesh" not in node:
            continue
        rot = matrix(node["rotation"])
        scale = node["scale"][0]
        move = np.array(node["translation"])
        primitive = gltf["meshes"][node["mesh"]]["primitives"][0]
        positions = accessor_array(gltf, blob, primitive["attributes"]["POSITION"]).astype(np.float64)
        normals = accessor_array(gltf, blob, primitive["attributes"]["NORMAL"]).astype(np.float64)
        uvs = accessor_array(gltf, blob, primitive["attributes"]["TEXCOORD_0"]).astype(np.float64)
        indices = accessor_array(gltf, blob, primitive["indices"]).astype(np.int64).reshape(-1, 3)
        world = positions * scale @ rot.T + move
        items.append((world, normals @ rot.T, uvs, indices, gltf["materials"][primitive["material"]]))
        lo, hi = np.minimum(lo, world.min(axis=0)), np.maximum(hi, world.max(axis=0))
    centre = (lo + hi) / 2
    view_points = [((w - centre) @ turn.T) for w, *_ in items]
    all_points = np.concatenate(view_points) if view_points else np.zeros((1, 3))
    reach = max(np.abs(all_points[:, 0]).max() / (width * 0.44), np.abs(all_points[:, 1]).max() / (height * 0.44), 1e-6)
    colour = np.zeros((height, width, 4))
    depth = np.full((height, width), np.inf)
    for (world, normals, uvs, faces, material), points in zip(items, view_points):
        sx = width / 2 + points[:, 0] / reach
        sy = height / 2 - points[:, 1] / reach
        sz = -points[:, 2]
        pbr = material["pbrMetallicRoughness"]
        factor = np.array(pbr["baseColorFactor"])
        texture = pictures[textures[pbr["baseColorTexture"]["index"]]["source"]] if "baseColorTexture" in pbr else None
        mask = material.get("alphaMode") == "MASK"
        blend = material.get("alphaMode") == "BLEND"
        turned_normals = normals @ turn.T
        for a, b, c in faces:
            xs, ys = sx[[a, b, c]], sy[[a, b, c]]
            x0, x1 = max(int(math.floor(xs.min())), 0), min(int(math.ceil(xs.max())), width - 1)
            y0, y1 = max(int(math.floor(ys.min())), 0), min(int(math.ceil(ys.max())), height - 1)
            if x0 > x1 or y0 > y1:
                continue
            area = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (xs[2] - xs[0]) * (ys[1] - ys[0])
            if abs(area) < 1e-9:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            w0 = ((xs[1] - gx) * (ys[2] - gy) - (xs[2] - gx) * (ys[1] - gy)) / area
            w1 = ((xs[2] - gx) * (ys[0] - gy) - (xs[0] - gx) * (ys[2] - gy)) / area
            w2 = 1 - w0 - w1
            inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
            if not inside.any():
                continue
            z = w0 * sz[a] + w1 * sz[b] + w2 * sz[c]
            region = depth[y0:y1 + 1, x0:x1 + 1]
            closer = inside & (z < region)
            if not closer.any():
                continue
            n = (w0[..., None] * turned_normals[a] + w1[..., None] * turned_normals[b] + w2[..., None] * turned_normals[c])
            n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-9)
            view_light = light @ turn.T
            facing = n[..., 2:3]
            n = np.where(facing < 0, -n, n)
            shade = 0.42 + 0.58 * np.clip((n * view_light).sum(axis=-1, keepdims=True), 0, 1)
            base = np.broadcast_to(factor, n.shape[:-1] + (4,)).copy()
            if texture is not None:
                u = w0 * uvs[a, 0] + w1 * uvs[b, 0] + w2 * uvs[c, 0]
                v = w0 * uvs[a, 1] + w1 * uvs[b, 1] + w2 * uvs[c, 1]
                th, tw = texture.shape[:2]
                tx = np.mod(np.floor(u * tw), tw).astype(int)
                ty = np.mod(np.floor(v * th), th).astype(int)
                texel = texture[ty, tx] / 255.0
                texel[..., :3] = linear(texel[..., :3] * 255)
                base = base * texel
            if mask:
                closer &= base[..., 3] >= 0.5
            if not closer.any():
                continue
            lit = base[..., :3] * shade
            if blend:
                alpha = base[..., 3:4]
                old = colour[y0:y1 + 1, x0:x1 + 1]
                mixed = old[..., :3] * (1 - alpha) + lit * alpha
                old[..., :3] = np.where(closer[..., None], mixed, old[..., :3])
                old[..., 3] = np.where(closer, np.maximum(old[..., 3], alpha[..., 0]), old[..., 3])
            else:
                old = colour[y0:y1 + 1, x0:x1 + 1]
                old[..., :3] = np.where(closer[..., None], lit, old[..., :3])
                old[..., 3] = np.where(closer, 1.0, old[..., 3])
                region[closer] = z[closer]
    srgb = np.where(colour[..., :3] <= 0.0031308, colour[..., :3] * 12.92, 1.055 * np.power(np.clip(colour[..., :3], 0, None), 1 / 2.4) - 0.055)
    out = np.dstack([np.clip(srgb, 0, 1), np.clip(colour[..., 3:4], 0, 1)])
    image = Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")
    # Сглаживание краёв: рисуем крупнее и уменьшаем — здесь уже готовый размер.
    return image


def preview(data):
    big = render(data, 1040, 800)
    return big.resize((520, 400), Image.LANCZOS)


# ---------------------------------------------------------------- сборка

def kits():
    return sorted(STOCK.glob("stock-*.dataset/stock-*.kit"))


def preset(path):
    return path.stem[len("stock-"):]


def digest(path):
    return hashlib.sha1(path.read_bytes() + (Path(__file__).read_bytes())).hexdigest()[:16]


def build(only=None):
    MODELS.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    total = 0
    for path in kits():
        name = preset(path)
        if only and name not in only:
            continue
        kit = read_kit(path)
        glb = to_glb(kit, name)
        read_glb(glb)
        (MODELS / f"{name}.glb").write_bytes(glb)
        (MODELS / f"{name}.json").write_text(json.dumps(sidecar(kit, digest(path)), ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        preview(glb).save(PREVIEWS / f"{name}.png", optimize=True)
        total += len(glb)
        roles_line = ", ".join(f"{r}" for r, _ in roles(kit))
        print(f"{name}: {len(glb) // 1024} КБ, деталей {len(kit['pieces'])}, материалы: {roles_line}")
    print(f"всего моделей: {total // 1024} КБ")
    return 0


def check():
    problems = []
    for path in kits():
        name = preset(path)
        glb, side, image = MODELS / f"{name}.glb", MODELS / f"{name}.json", PREVIEWS / f"{name}.png"
        if not (glb.exists() and side.exists() and image.exists()):
            problems.append(f"{name}: нет модели, описания или картинки")
            continue
        if json.loads(side.read_text(encoding="utf-8")).get("source") != digest(path):
            problems.append(f"{name}: устарела — запустите build")
        read_glb(glb.read_bytes())
    for problem in problems:
        print(problem)
    print(f"моделей: {len(kits())}, замечаний: {len(problems)}")
    return 1 if problems else 0


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    sys.exit(build(set(sys.argv[2:]) or None) if command == "build" else check())
